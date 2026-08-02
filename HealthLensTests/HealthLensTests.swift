import HealthKit
import XCTest

@testable import HealthLens

/// Core integration smoke tests for the HealthLens export pipeline
final class HealthLensTests: XCTestCase {

  // MARK: - Authorization flow

  func testHealthStoreAuthorizationRequested() {
    let mockStore = MockHealthStore()
    let viewModel = ContentViewModel(healthStore: mockStore)
    viewModel.clearExportQueue()

    let typeToSelect = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    viewModel.toggleTypeIdentifier(.stepCount)

    let expectation = self.expectation(description: "Authorization Requested")

    Task {
      _ = try? await viewModel.asyncExportHealthData()

      XCTAssertEqual(mockStore.authorizationRequests.count, 1)
      let (share, read) = mockStore.authorizationRequests.first!
      XCTAssertNil(share)
      XCTAssertTrue(read?.contains(typeToSelect) ?? false)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 5.0, handler: nil)
  }

  // MARK: - Full CSV pipeline

  func testFullCSVExportPipeline() {
    let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let samples = TestSampleFactory.makeGappedSamples(
      type: .stepCount, unit: .count(), count: 10, value: 100)

    let mockStore = MockHealthStoreWithData(
      samples: [stepType: samples],
      units: [stepType: .count()])

    let viewModel = ContentViewModel(healthStore: mockStore)
    viewModel.clearExportQueue()
    viewModel.selectedExportFormat = .csv
    viewModel.toggleTypeIdentifier(.stepCount)

    let expectation = self.expectation(description: "CSV Export")

    Task {
      let url = try! await viewModel.asyncExportHealthData()

      XCTAssertTrue(url.lastPathComponent.hasSuffix(".csv"))
      XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

      if let content = try? String(contentsOf: url, encoding: .utf8) {
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertGreaterThan(lines.count, 1, "Should have header + data rows")
      }

      try? FileManager.default.removeItem(at: url)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 10.0, handler: nil)
  }

  // MARK: - Full XLSX pipeline

  func testFullXLSXExportPipeline() {
    let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let samples = TestSampleFactory.makeGappedSamples(
      type: .stepCount, unit: .count(), count: 10, value: 100)

    let mockStore = MockHealthStoreWithData(
      samples: [stepType: samples],
      units: [stepType: .count()])

    let viewModel = ContentViewModel(healthStore: mockStore)
    viewModel.clearExportQueue()
    viewModel.selectedExportFormat = .xlsx
    viewModel.toggleTypeIdentifier(.stepCount)

    let expectation = self.expectation(description: "XLSX Export")

    Task {
      let url = try! await viewModel.asyncExportHealthData()

      XCTAssertTrue(url.lastPathComponent.hasSuffix(".xlsx"))
      XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

      try? FileManager.default.removeItem(at: url)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 10.0, handler: nil)
  }

  // MARK: - Toggle and clear

  func testToggleTypeIdentifier() {
    let viewModel = ContentViewModel(healthStore: MockHealthStore())
    // Clear any persisted state from @AppStorage
    viewModel.clearExportQueue()

    XCTAssertFalse(viewModel.selectedQuantityTypes.contains(.stepCount))
    viewModel.toggleTypeIdentifier(.stepCount)
    XCTAssertTrue(viewModel.selectedQuantityTypes.contains(.stepCount))
    viewModel.toggleTypeIdentifier(.stepCount)
    XCTAssertFalse(viewModel.selectedQuantityTypes.contains(.stepCount))
  }

  func testClearExportQueue() {
    let viewModel = ContentViewModel(healthStore: MockHealthStore())
    viewModel.clearExportQueue()

    viewModel.toggleTypeIdentifier(.stepCount)
    viewModel.toggleTypeIdentifier(.heartRate)
    XCTAssertEqual(viewModel.selectedQuantityTypes.count, 2)

    viewModel.clearExportQueue()
    XCTAssertTrue(viewModel.selectedQuantityTypes.isEmpty)
  }
}

final class HealthDataExportServiceTests: XCTestCase {

  func testNoSelectionFailsBeforeHealthStoreWork() async {
    let store = MockHealthStoreClient()
    do {
      _ = try await makeService(store: store).export(
        ExportRequest(quantityIdentifiers: [], format: .csv, dateInterval: nil))
      XCTFail("Expected noTypesSelected")
    } catch HealthExportError.noTypesSelected {
      XCTAssertTrue(store.queriedTypes.isEmpty)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testUnavailableHealthDataFails() async {
    let store = MockHealthStoreClient()
    store.isHealthDataAvailable = false
    do {
      _ = try await makeService(store: store).export(
        ExportRequest(quantityIdentifiers: [.stepCount], format: .csv, dateInterval: nil))
      XCTFail("Expected healthDataUnavailable")
    } catch HealthExportError.healthDataUnavailable {
      XCTAssertTrue(store.queriedTypes.isEmpty)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testAuthorizationFailureDoesNotQuery() async {
    let store = MockHealthStoreClient()
    store.authorizationError = TestExportError.failed
    do {
      _ = try await makeService(store: store).export(
        ExportRequest(quantityIdentifiers: [.stepCount], format: .csv, dateInterval: nil))
      XCTFail("Expected authorization failure")
    } catch HealthExportError.authorizationFailed {
      XCTAssertTrue(store.queriedTypes.isEmpty)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testPreferredUnitFailureDoesNotQuery() async {
    let store = MockHealthStoreClient()
    store.preferredUnitsError = TestExportError.failed
    do {
      _ = try await makeService(store: store).export(
        ExportRequest(quantityIdentifiers: [.stepCount], format: .csv, dateInterval: nil))
      XCTFail("Expected preferred-unit failure")
    } catch HealthExportError.preferredUnitsFailed {
      XCTAssertTrue(store.queriedTypes.isEmpty)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testEveryTypeIsQueriedWithCapAndDatePredicate() async throws {
    let store = MockHealthStoreClient()
    let interval = DateInterval(
      start: Date(timeIntervalSince1970: 100),
      end: Date(timeIntervalSince1970: 200))
    _ = try await makeService(store: store).export(
      ExportRequest(
        quantityIdentifiers: [.heartRate, .stepCount],
        format: .csv,
        dateInterval: interval))

    XCTAssertEqual(Set(store.queriedTypes), Set([
      HKQuantityTypeIdentifier.heartRate.rawValue,
      HKQuantityTypeIdentifier.stepCount.rawValue,
    ]))
    XCTAssertEqual(store.queryLimits, [sample_cap, sample_cap])
    XCTAssertEqual(store.predicateCount, 2)
  }

  func testQueryFailureProducesNoPartialFile() async {
    let store = MockHealthStoreClient()
    store.queryErrors[HKQuantityTypeIdentifier.heartRate.rawValue] = TestExportError.failed
    let writer = RecordingCSVWriter()
    do {
      _ = try await makeService(store: store, csvWriter: writer).export(
        ExportRequest(
          quantityIdentifiers: [.heartRate, .stepCount],
          format: .csv,
          dateInterval: nil))
      XCTFail("Expected query failure")
    } catch HealthExportError.sampleQueryFailed {
      XCTAssertEqual(writer.writeCount, 0)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testRecordsAreDeterministicallyOrderedAndUseFallbackUnit() async throws {
    let store = MockHealthStoreClient()
    let earlier = Date(timeIntervalSince1970: 100)
    let later = Date(timeIntervalSince1970: 500)
    store.samplesByType[HKQuantityTypeIdentifier.stepCount.rawValue] = [
      TestSampleFactory.makeSample(
        type: .stepCount,
        value: 2,
        start: later,
        end: later.addingTimeInterval(1)),
      TestSampleFactory.makeSample(
        type: .stepCount,
        value: 1,
        start: earlier,
        end: earlier.addingTimeInterval(1)),
    ]
    store.samplesByType[HKQuantityTypeIdentifier.heartRate.rawValue] = [
      TestSampleFactory.makeSample(
        type: .heartRate,
        unit: .count().unitDivided(by: .minute()),
        value: 70,
        start: earlier,
        end: earlier.addingTimeInterval(1))
    ]
    let writer = RecordingCSVWriter()

    _ = try await makeService(store: store, csvWriter: writer).export(
      ExportRequest(
        quantityIdentifiers: [.stepCount, .heartRate],
        format: .csv,
        dateInterval: nil))

    XCTAssertEqual(writer.records.map(\.category), ["Heart Rate", "Step Count", "Step Count"])
    XCTAssertEqual(Array(writer.records.suffix(2)).map(\.date), [earlier, later])
    XCTAssertEqual(writer.records.last?.unit, HKUnit.count().unitString)
  }

  func testMissingCompatibleUnitIsTypedFailure() async {
    let store = MockHealthStoreClient()
    do {
      _ = try await makeService(store: store, fallbackUnits: []).export(
        ExportRequest(quantityIdentifiers: [.stepCount], format: .csv, dateInterval: nil))
      XCTFail("Expected missing unit")
    } catch HealthExportError.missingCompatibleUnit(let identifier) {
      XCTAssertEqual(identifier, HKQuantityTypeIdentifier.stepCount.rawValue)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testEmptyQueryProducesHeaderOnlyArtifact() async throws {
    let store = MockHealthStoreClient()
    let artifact = try await makeService(store: store).export(
      ExportRequest(quantityIdentifiers: [.stepCount], format: .csv, dateInterval: nil))
    defer { try? FileManager.default.removeItem(at: artifact.url) }
    let content = try String(contentsOf: artifact.url, encoding: .utf8)
    XCTAssertEqual(content, "Datetime,Category,Unit,Value\n")
  }

  func testFormatSelectsOnlyRequestedWriter() async throws {
    let store = MockHealthStoreClient()
    let csv = RecordingCSVWriter()
    let xlsx = RecordingXLSXWriter()
    _ = try await makeService(store: store, csvWriter: csv, xlsxWriter: xlsx).export(
      ExportRequest(quantityIdentifiers: [.stepCount], format: .xlsx, dateInterval: nil))
    XCTAssertEqual(csv.writeCount, 0)
    XCTAssertEqual(xlsx.writeCount, 1)
  }

  private func makeService(
    store: MockHealthStoreClient,
    csvWriter: CSVWriting? = nil,
    xlsxWriter: XLSXWriting? = nil,
    fallbackUnits: [HKUnit] = [.count(), .count().unitDivided(by: .minute())]
  ) -> HealthDataExportService {
    HealthDataExportService(
      healthStore: store,
      processor: HealthSampleProcessor(fallbackUnits: fallbackUnits),
      csvWriter: csvWriter ?? makeCSVWriter(),
      xlsxWriter: xlsxWriter ?? RecordingXLSXWriter(),
      categoryNames: [
        .heartRate: "Heart Rate",
        .stepCount: "Step Count",
      ])
  }

  private func makeCSVWriter() -> CSVWriter {
    CSVWriter(
      headers: ["Datetime", "Category", "Unit", "Value"],
      dateFormatter: testServiceDateFormatter(),
      numberFormatter: testServiceNumberFormatter())
  }
}

final class TransferableExportTests: XCTestCase {

  func testDeferredCSVClosureRunsExactlyOnce() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("share.csv")
    try "value".write(to: url, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: url) }
    var calls = 0
    let target = CSVExportFile(
      collectData: {
        calls += 1
        return url
      },
      fileName: { "health-data" })

    let result = try await target.shareURL()
    XCTAssertEqual(calls, 1)
    XCTAssertEqual(result.pathExtension, "csv")
    XCTAssertTrue(FileManager.default.fileExists(atPath: result.path))
  }

  func testFailedShareThrowsAndSetsViewModelAlertWithoutIncrementingAnalytics() async {
    let viewModel = ContentViewModel(exporter: FailingExporter())
    viewModel.clearExportQueue()
    viewModel.toggleTypeIdentifier(.stepCount)
    viewModel.timesExported = 0
    do {
      _ = try await viewModel.csvShareTarget.shareURL()
      XCTFail("Expected failure")
    } catch {
      XCTAssertNotNil(viewModel.exportErrorMessage)
      XCTAssertEqual(viewModel.timesExported, 0)
    }
  }
}

private enum TestExportError: Error {
  case failed
}

private final class MockHealthStoreClient: HealthStoreClient {
  var isHealthDataAvailable = true
  var status = HKAuthorizationStatus.notDetermined
  var authorizationError: Error?
  var preferredUnitsError: Error?
  var preferredUnitData: [HKQuantityType: HKUnit] = [:]
  var samplesByType: [String: [HKQuantitySample]] = [:]
  var queryErrors: [String: Error] = [:]
  var queriedTypes: [String] = []
  var queryLimits: [Int] = []
  var predicateCount = 0
  private let lock = NSLock()

  func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
    status
  }

  func requestAuthorization(read types: Set<HKObjectType>) async throws {
    if let authorizationError { throw authorizationError }
  }

  func preferredUnits(for types: Set<HKQuantityType>) async throws
    -> [HKQuantityType: HKUnit]
  {
    if let preferredUnitsError { throw preferredUnitsError }
    return preferredUnitData
  }

  func samples(
    for type: HKQuantityType,
    predicate: NSPredicate?,
    limit: Int
  ) async throws -> [HKQuantitySample] {
    lock.withLock {
      queriedTypes.append(type.identifier)
      queryLimits.append(limit)
      if predicate != nil { predicateCount += 1 }
    }
    if let error = queryErrors[type.identifier] { throw error }
    return samplesByType[type.identifier] ?? []
  }
}

private final class RecordingCSVWriter: CSVWriting {
  var records: [ExportRecord] = []
  var writeCount = 0

  func write(records: [ExportRecord]) throws -> URL {
    writeCount += 1
    self.records = records
    return FileManager.default.temporaryDirectory.appendingPathComponent("recording.csv")
  }
}

private final class RecordingXLSXWriter: XLSXWriting {
  var writeCount = 0

  func write(records: [ExportRecord]) throws -> URL {
    writeCount += 1
    return FileManager.default.temporaryDirectory.appendingPathComponent("recording.xlsx")
  }
}

private struct FailingExporter: HealthDataExporting {
  func export(_ request: ExportRequest) async throws -> ExportArtifact {
    throw HealthExportError.csvWriteFailed(TestExportError.failed)
  }
}

private func testServiceDateFormatter() -> DateFormatter {
  let formatter = DateFormatter()
  formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
  formatter.locale = Locale(identifier: "en_US_POSIX")
  formatter.timeZone = TimeZone(secondsFromGMT: 0)
  return formatter
}

private func testServiceNumberFormatter() -> NumberFormatter {
  let formatter = NumberFormatter()
  formatter.numberStyle = .decimal
  formatter.minimumFractionDigits = 2
  formatter.maximumFractionDigits = 2
  formatter.locale = Locale(identifier: "en_US_POSIX")
  return formatter
}
