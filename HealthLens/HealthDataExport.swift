import Foundation
import HealthKit
import libxlsxwriter

struct ExportRequest {
  let quantityIdentifiers: Set<HKQuantityTypeIdentifier>
  let format: ExportFormat
  let dateInterval: DateInterval?
}

struct ExportArtifact {
  let url: URL
  let suggestedFilename: String
}

struct ExportRecord: Equatable {
  let date: Date
  let category: String
  let unit: String
  let value: Double
}

enum HealthExportError: LocalizedError {
  case noTypesSelected
  case healthDataUnavailable
  case authorizationFailed(Error?)
  case preferredUnitsFailed(Error)
  case sampleQueryFailed(String, Error)
  case missingCompatibleUnit(String)
  case csvWriteFailed(Error)
  case xlsxCreationFailed
  case xlsxFinalizationFailed(Int32)

  var errorDescription: String? {
    switch self {
    case .noTypesSelected:
      return String(localized: "Select at least one health category to export.")
    case .healthDataUnavailable:
      return String(localized: "Health data is unavailable on this device.")
    case .authorizationFailed:
      return String(localized: "Health data access was not granted.")
    case .preferredUnitsFailed:
      return String(localized: "HealthLens could not load your preferred health units.")
    case .sampleQueryFailed(let identifier, _):
      return String(localized: "HealthLens could not load \(identifier).")
    case .missingCompatibleUnit(let identifier):
      return String(localized: "HealthLens could not find a compatible unit for \(identifier).")
    case .csvWriteFailed:
      return String(localized: "HealthLens could not create the CSV file.")
    case .xlsxCreationFailed, .xlsxFinalizationFailed:
      return String(localized: "HealthLens could not create the XLSX file.")
    }
  }
}

protocol HealthDataExporting {
  func export(_ request: ExportRequest) async throws -> ExportArtifact
}

protocol HealthStoreClient {
  var isHealthDataAvailable: Bool { get }
  func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus
  func requestAuthorization(read types: Set<HKObjectType>) async throws
  func preferredUnits(for types: Set<HKQuantityType>) async throws -> [HKQuantityType: HKUnit]
  func samples(
    for type: HKQuantityType,
    predicate: NSPredicate?,
    limit: Int
  ) async throws -> [HKQuantitySample]
}

protocol CSVWriting {
  func write(records: [ExportRecord]) throws -> URL
}

protocol XLSXWriting {
  func write(records: [ExportRecord]) throws -> URL
}

final class HKHealthStoreClient: HealthStoreClient {
  private let store: HKHealthStore

  init(store: HKHealthStore = HKHealthStore()) {
    self.store = store
  }

  var isHealthDataAvailable: Bool {
    HKHealthStore.isHealthDataAvailable()
  }

  func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
    store.authorizationStatus(for: type)
  }

  func requestAuthorization(read types: Set<HKObjectType>) async throws {
    try await store.requestAuthorization(toShare: [], read: types)
  }

  func preferredUnits(for types: Set<HKQuantityType>) async throws
    -> [HKQuantityType: HKUnit]
  {
    try await withCheckedThrowingContinuation { continuation in
      store.preferredUnits(for: types) { units, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: units)
        }
      }
    }
  }

  func samples(
    for type: HKQuantityType,
    predicate: NSPredicate?,
    limit: Int
  ) async throws -> [HKQuantitySample] {
    let descriptor = HKSampleQueryDescriptor(
      predicates: [.quantitySample(type: type, predicate: predicate)],
      sortDescriptors: [SortDescriptor(\.startDate)],
      limit: limit)
    return try await descriptor.result(for: store)
  }
}

/// Keeps the existing callback mocks useful while production uses `HKHealthStoreClient`.
final class LegacyHealthStoreClient: HealthStoreClient {
  private let store: HealthStoreProtocol

  init(store: HealthStoreProtocol) {
    self.store = store
  }

  var isHealthDataAvailable: Bool {
    store.isHealthDataAvailable()
  }

  func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
    store.authorizationStatus(for: type)
  }

  func requestAuthorization(read types: Set<HKObjectType>) async throws {
    try await withCheckedThrowingContinuation { continuation in
      store.requestAuthorization(toShare: nil, read: types) { success, error in
        if success {
          continuation.resume()
        } else {
          continuation.resume(
            throwing: HealthExportError.authorizationFailed(error))
        }
      }
    }
  }

  func preferredUnits(for types: Set<HKQuantityType>) async throws
    -> [HKQuantityType: HKUnit]
  {
    try await withCheckedThrowingContinuation { continuation in
      store.preferredUnits(for: types) { units, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: units)
        }
      }
    }
  }

  func samples(
    for type: HKQuantityType,
    predicate: NSPredicate?,
    limit: Int
  ) async throws -> [HKQuantitySample] {
    try await withCheckedThrowingContinuation { continuation in
      store.executeSampleQuery(
        sampleType: type,
        predicate: predicate,
        limit: limit,
        sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
      ) { _, samples, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: (samples ?? []).compactMap { $0 as? HKQuantitySample })
        }
      }
    }
  }
}

struct HealthSampleProcessor {
  let fallbackUnits: [HKUnit]

  func unit(for type: HKQuantityType, preferredUnit: HKUnit?) -> HKUnit? {
    if let preferredUnit, type.is(compatibleWith: preferredUnit) {
      return preferredUnit
    }
    return fallbackUnits.first { type.is(compatibleWith: $0) }
  }

  func process(
    _ samples: [HKQuantitySample],
    for type: HKQuantityType,
    unit: HKUnit
  ) -> [HKQuantitySample] {
    var result = mergeConsecutiveSamples(samples, for: type, unit: unit)
    if result.count > dense_sample_threshold {
      result = aggregateSamples(
        result,
        for: type,
        interval: time_bucket_interval,
        unit: unit)
    }
    return result.sorted { $0.startDate < $1.startDate }
  }

  func aggregateSamples(
    _ samples: [HKQuantitySample],
    for type: HKQuantityType,
    interval: TimeInterval,
    unit: HKUnit
  ) -> [HKQuantitySample] {
    guard interval > 0, !samples.isEmpty else { return samples }

    let sortedSamples = samples.sorted { $0.startDate < $1.startDate }
    var aggregatedSamples: [HKQuantitySample] = []
    var currentBucketStart: Date?
    var currentBucketSamples: [HKQuantitySample] = []

    func appendBucket(start: Date, samples: [HKQuantitySample]) {
      guard
        let sample = combine(
          samples,
          start: start,
          end: start.addingTimeInterval(interval),
          type: type,
          unit: unit,
          weightedDiscrete: false)
      else { return }
      aggregatedSamples.append(sample)
    }

    for sample in sortedSamples {
      let timestamp = floor(sample.startDate.timeIntervalSince1970 / interval) * interval
      let bucketStart = Date(timeIntervalSince1970: timestamp)
      if let currentStart = currentBucketStart, bucketStart > currentStart {
        appendBucket(start: currentStart, samples: currentBucketSamples)
        currentBucketStart = bucketStart
        currentBucketSamples = [sample]
      } else {
        currentBucketStart = currentBucketStart ?? bucketStart
        currentBucketSamples.append(sample)
      }
    }

    if let currentBucketStart {
      appendBucket(start: currentBucketStart, samples: currentBucketSamples)
    }
    return aggregatedSamples
  }

  func mergeConsecutiveSamples(
    _ samples: [HKQuantitySample],
    for type: HKQuantityType,
    unit: HKUnit
  ) -> [HKQuantitySample] {
    guard !samples.isEmpty else { return [] }
    let sortedSamples = samples.sorted { $0.startDate < $1.startDate }
    var mergedSamples: [HKQuantitySample] = []
    var currentBatch: [HKQuantitySample] = []

    for sample in sortedSamples {
      guard let first = currentBatch.first, let last = currentBatch.last else {
        currentBatch.append(sample)
        continue
      }
      let gap = abs(sample.startDate.timeIntervalSince(last.endDate))
      let duration = sample.endDate.timeIntervalSince(first.startDate)
      if gap < merge_gap_tolerance, duration < max_merged_duration {
        currentBatch.append(sample)
      } else {
        if let merged = combine(
          currentBatch,
          start: first.startDate,
          end: last.endDate,
          type: type,
          unit: unit,
          weightedDiscrete: true)
        {
          mergedSamples.append(merged)
        }
        currentBatch = [sample]
      }
    }

    if let first = currentBatch.first, let last = currentBatch.last,
      let merged = combine(
        currentBatch,
        start: first.startDate,
        end: last.endDate,
        type: type,
        unit: unit,
        weightedDiscrete: true)
    {
      mergedSamples.append(merged)
    }
    return mergedSamples
  }

  private func combine(
    _ samples: [HKQuantitySample],
    start: Date,
    end: Date,
    type: HKQuantityType,
    unit: HKUnit,
    weightedDiscrete: Bool
  ) -> HKQuantitySample? {
    guard !samples.isEmpty else { return nil }
    let value: Double
    if type.aggregationStyle == .cumulative {
      value = samples.reduce(0) { $0 + $1.quantity.doubleValue(for: unit) }
    } else if weightedDiscrete {
      let duration = samples.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
      if duration > 0 {
        value =
          samples.reduce(0) {
            $0 + $1.quantity.doubleValue(for: unit)
              * $1.endDate.timeIntervalSince($1.startDate)
          } / duration
      } else {
        value =
          samples.reduce(0) { $0 + $1.quantity.doubleValue(for: unit) }
          / Double(samples.count)
      }
    } else {
      value =
        samples.reduce(0) { $0 + $1.quantity.doubleValue(for: unit) }
        / Double(samples.count)
    }
    return HKQuantitySample(
      type: type,
      quantity: HKQuantity(unit: unit, doubleValue: value),
      start: start,
      end: end)
  }
}

struct CSVWriter: CSVWriting {
  let headers: [String]
  let dateFormatter: DateFormatter
  let numberFormatter: NumberFormatter
  var directory: URL = FileManager.default.temporaryDirectory

  func sanitize(_ input: String) -> String {
    let escaped = input.replacingOccurrences(of: "\"", with: "\"\"")
    if escaped.contains(",") || escaped.contains("\n") || escaped.contains("\"") {
      return "\"\(escaped)\""
    }
    return escaped
  }

  func write(records: [ExportRecord]) throws -> URL {
    do {
      try Task.checkCancellation()
      let url = directory.appendingPathComponent("HealthData\(UUID().uuidString).csv")
      var rows: [String] = []
      rows.reserveCapacity(records.count + 1)
      rows.append(headers.map(sanitize).joined(separator: ","))
      for record in records {
        try Task.checkCancellation()
        let value =
          numberFormatter.string(from: record.value as NSNumber) ?? String(record.value)
        rows.append(
          [
            dateFormatter.string(from: record.date),
            record.category,
            record.unit,
            value,
          ].map(sanitize).joined(separator: ","))
      }
      try (rows.joined(separator: "\n") + "\n")
        .write(to: url, atomically: true, encoding: .utf8)
      return url
    } catch is CancellationError {
      throw CancellationError()
    } catch {
      throw HealthExportError.csvWriteFailed(error)
    }
  }
}

struct XLSXWriter: XLSXWriting {
  private static let workbookLock = NSLock()

  let headers: [String]
  let dateFormatter: DateFormatter
  let numberFormatter: NumberFormatter
  var directory: URL = FileManager.default.temporaryDirectory

  func write(records: [ExportRecord]) throws -> URL {
    Self.workbookLock.lock()
    defer { Self.workbookLock.unlock() }

    try Task.checkCancellation()
    let url = directory.appendingPathComponent("HealthData\(UUID().uuidString).xlsx")
    guard let workbook = workbook_new(url.path) else {
      throw HealthExportError.xlsxCreationFailed
    }

    var shouldRemoveFile = true
    defer {
      if shouldRemoveFile {
        try? FileManager.default.removeItem(at: url)
      }
    }

    guard let worksheet = workbook_add_worksheet(workbook, String(localized: "Data")) else {
      _ = workbook_close(workbook)
      throw HealthExportError.xlsxCreationFailed
    }

    let headerFormat = workbook_add_format(workbook)
    format_set_bold(headerFormat)
    format_set_align(headerFormat, UInt8(LXW_ALIGN_CENTER.rawValue))
    let dateFormat = workbook_add_format(workbook)
    format_set_num_format(dateFormat, dateFormatter.dateFormat ?? "yyyy-MM-dd HH:mm:ss")
    let numberFormat = workbook_add_format(workbook)
    format_set_num_format(numberFormat, numberFormatter.positiveFormat ?? "#,##0.00")

    worksheet_set_column_pixels(worksheet, 0, 0, 120, nil)
    worksheet_set_column_pixels(worksheet, 1, 1, 80, nil)
    worksheet_set_column_pixels(worksheet, 2, 2, 40, nil)
    worksheet_set_column_pixels(worksheet, 3, 3, 80, nil)

    for (column, header) in headers.enumerated() {
      worksheet_write_string(worksheet, 0, lxw_col_t(column), header, headerFormat)
    }
    for (index, record) in records.enumerated() {
      do {
        try Task.checkCancellation()
      } catch {
        _ = workbook_close(workbook)
        throw error
      }
      let row = lxw_row_t(index + 1)
      worksheet_write_unixtime(
        worksheet,
        row,
        0,
        Int64(record.date.timeIntervalSince1970),
        dateFormat)
      worksheet_write_string(worksheet, row, 1, record.category, nil)
      worksheet_write_string(worksheet, row, 2, record.unit, nil)
      worksheet_write_number(worksheet, row, 3, record.value, numberFormat)
    }

    let closeResult = workbook_close(workbook)
    guard closeResult == LXW_NO_ERROR else {
      throw HealthExportError.xlsxFinalizationFailed(Int32(closeResult.rawValue))
    }
    shouldRemoveFile = false
    return url
  }
}

final class HealthDataExportService: HealthDataExporting {
  private let healthStore: HealthStoreClient
  private let processor: HealthSampleProcessor
  private let csvWriter: CSVWriting
  private let xlsxWriter: XLSXWriting
  private let categoryNames: [HKQuantityTypeIdentifier: String]

  init(
    healthStore: HealthStoreClient,
    processor: HealthSampleProcessor,
    csvWriter: CSVWriting,
    xlsxWriter: XLSXWriting,
    categoryNames: [HKQuantityTypeIdentifier: String]
  ) {
    self.healthStore = healthStore
    self.processor = processor
    self.csvWriter = csvWriter
    self.xlsxWriter = xlsxWriter
    self.categoryNames = categoryNames
  }

  func export(_ request: ExportRequest) async throws -> ExportArtifact {
    guard !request.quantityIdentifiers.isEmpty else {
      throw HealthExportError.noTypesSelected
    }
    guard healthStore.isHealthDataAvailable else {
      throw HealthExportError.healthDataUnavailable
    }

    let identifiers = request.quantityIdentifiers.sorted { $0.rawValue < $1.rawValue }
    let types = try identifiers.map { identifier -> HKQuantityType in
      guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
        throw HealthExportError.sampleQueryFailed(
          identifier.rawValue,
          CocoaError(.validationMissingMandatoryProperty))
      }
      return type
    }
    let objectTypes = Set(types.map { $0 as HKObjectType })

    if types.contains(where: {
      let status = healthStore.authorizationStatus(for: $0)
      return status == .notDetermined || status == .sharingDenied
    }) {
      do {
        try await healthStore.requestAuthorization(read: objectTypes)
      } catch let error as HealthExportError {
        throw error
      } catch {
        throw HealthExportError.authorizationFailed(error)
      }
    }

    let preferredUnits: [HKQuantityType: HKUnit]
    do {
      preferredUnits = try await healthStore.preferredUnits(for: Set(types))
    } catch {
      throw HealthExportError.preferredUnitsFailed(error)
    }

    let predicate = request.dateInterval.map {
      HKQuery.predicateForSamples(withStart: $0.start, end: $0.end, options: [])
    }
    let queriedSamples = try await withThrowingTaskGroup(
      of: (String, HKQuantityType, [HKQuantitySample]).self,
      returning: [(String, HKQuantityType, [HKQuantitySample])].self
    ) { group in
      for type in types {
        group.addTask {
          do {
            let samples = try await self.healthStore.samples(
              for: type,
              predicate: predicate,
              limit: sample_cap)
            return (type.identifier, type, samples)
          } catch is CancellationError {
            throw CancellationError()
          } catch {
            throw HealthExportError.sampleQueryFailed(type.identifier, error)
          }
        }
      }

      var results: [(String, HKQuantityType, [HKQuantitySample])] = []
      do {
        for try await result in group {
          results.append(result)
        }
      } catch {
        group.cancelAll()
        throw error
      }
      return results.sorted { $0.0 < $1.0 }
    }

    try Task.checkCancellation()
    var records: [ExportRecord] = []
    records.reserveCapacity(queriedSamples.reduce(0) { $0 + $1.2.count })
    for (identifierString, type, samples) in queriedSamples {
      guard let unit = processor.unit(for: type, preferredUnit: preferredUnits[type]) else {
        throw HealthExportError.missingCompatibleUnit(identifierString)
      }
      let identifier = HKQuantityTypeIdentifier(rawValue: identifierString)
      let category = categoryNames[identifier] ?? String(localized: "Unknown")
      for sample in processor.process(samples, for: type, unit: unit) {
        records.append(
          ExportRecord(
            date: sample.startDate,
            category: category,
            unit: unit.unitString,
            value: sample.quantity.doubleValue(for: unit)))
      }
    }

    try Task.checkCancellation()
    let url: URL
    switch request.format {
    case .csv:
      url = try csvWriter.write(records: records)
    case .xlsx:
      url = try xlsxWriter.write(records: records)
    }
    return ExportArtifact(url: url, suggestedFilename: url.lastPathComponent)
  }
}
