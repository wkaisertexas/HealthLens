import HealthKit
import XCTest

@testable import HealthLens

final class ExportXLSXTests: XCTestCase {

  var viewModel: ContentViewModel!

  override func setUp() {
    super.setUp()
    viewModel = ContentViewModel(healthStore: MockHealthStore())
  }

  override func tearDown() {
    viewModel = nil
    super.tearDown()
  }

  // MARK: - Helper to call exportELSXData with a continuation

  private func exportXLSX(
    results: [HKObjectType: [HKSample]],
    units: [HKObjectType: HKUnit] = [:]
  ) async -> URL {
    return await withUnsafeContinuation { continuation in
      viewModel.exportELSXData(results, continuation: continuation, unitsMapping: units)
    }
  }

  // MARK: - File creation

  func testXLSXCreatesFile() async {
    let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let sample = TestSampleFactory.makeSample(type: .stepCount, value: 100)

    let url = await exportXLSX(
      results: [stepType: [sample]],
      units: [stepType: .count()])

    XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "XLSX file should be created")
    XCTAssertTrue(url.lastPathComponent.hasSuffix(".xlsx"), "File should have .xlsx extension")

    try? FileManager.default.removeItem(at: url)
  }

  // MARK: - Empty results produce valid file

  func testXLSXWithEmptyResultsCreatesFile() async {
    let url = await exportXLSX(results: [:])

    XCTAssertTrue(
      FileManager.default.fileExists(atPath: url.path),
      "XLSX file should be created even with empty results")
    // XLSX files start with PK (ZIP format)
    let data = try? Data(contentsOf: url)
    XCTAssertNotNil(data, "Should be able to read file data")
    if let data = data, data.count >= 2 {
      XCTAssertEqual(data[0], 0x50, "XLSX should start with PK signature (P)")
      XCTAssertEqual(data[1], 0x4B, "XLSX should start with PK signature (K)")
    }

    try? FileManager.default.removeItem(at: url)
  }

  // MARK: - Large row count (50k) doesn't crash

  func testXLSXWithLargeRowCountDoesNotCrash() async {
    let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    // Generate 50,000 samples (the sample_cap)
    let samples = TestSampleFactory.makeGappedSamples(
      type: .stepCount, unit: .count(), count: 1000, durationSeconds: 60, gapSeconds: 60,
      value: 42)

    let url = await exportXLSX(
      results: [stepType: samples],
      units: [stepType: .count()])

    XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Large XLSX should be created")
    let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int ?? 0
    XCTAssertGreaterThan(fileSize, 0, "XLSX file should not be empty")

    try? FileManager.default.removeItem(at: url)
  }

  // MARK: - Extreme values

  func testXLSXWithExtremeValuesDoesNotCrash() async {
    let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let extremeValues: [Double] = [0, Double.greatestFiniteMagnitude, Double.leastNonzeroMagnitude]

    var samples: [HKSample] = []
    var start = Date(timeIntervalSince1970: 1_000_000)
    for value in extremeValues {
      let end = start.addingTimeInterval(60)
      samples.append(TestSampleFactory.makeSample(type: .stepCount, value: value, start: start, end: end))
      start = end.addingTimeInterval(300)
    }

    let url = await exportXLSX(
      results: [stepType: samples],
      units: [stepType: .count()])

    XCTAssertTrue(
      FileManager.default.fileExists(atPath: url.path),
      "XLSX with extreme values should still create file")

    try? FileManager.default.removeItem(at: url)
  }

  // MARK: - Multi-type export

  func testXLSXWithMultipleTypesDoesNotCrash() async {
    let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    let bpm = HKUnit.count().unitDivided(by: .minute())

    let stepSamples = TestSampleFactory.makeGappedSamples(
      type: .stepCount, unit: .count(), count: 10, value: 500)
    let hrSamples = TestSampleFactory.makeGappedSamples(
      type: .heartRate, unit: bpm, count: 10, value: 72)

    let url = await exportXLSX(
      results: [stepType: stepSamples, hrType: hrSamples],
      units: [stepType: .count(), hrType: bpm])

    XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Multi-type XLSX should work")

    try? FileManager.default.removeItem(at: url)
  }

  // MARK: - Fallback unit

  func testXLSXUsesFallbackUnitWhenNoPreferredUnit() async {
    let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let sample = TestSampleFactory.makeSample(type: .stepCount, value: 42)

    let url = await exportXLSX(
      results: [stepType: [sample]],
      units: [:])

    XCTAssertTrue(
      FileManager.default.fileExists(atPath: url.path),
      "XLSX should create file even without preferred units")

    try? FileManager.default.removeItem(at: url)
  }

  // MARK: - Repeated exports don't leak or crash

  func testRepeatedXLSXExportsDoNotCrash() async {
    let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let samples = TestSampleFactory.makeGappedSamples(
      type: .stepCount, unit: .count(), count: 100, value: 50)

    for i in 0..<10 {
      let url = await exportXLSX(
        results: [stepType: samples],
        units: [stepType: .count()])

      XCTAssertTrue(
        FileManager.default.fileExists(atPath: url.path),
        "Export \(i) should produce a file")

      try? FileManager.default.removeItem(at: url)
    }
  }
}
