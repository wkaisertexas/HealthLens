import HealthKit
import XCTest

@testable import HealthLens

final class ExportCSVTests: XCTestCase {

  var viewModel: ContentViewModel!

  override func setUp() {
    super.setUp()
    viewModel = ContentViewModel(healthStore: MockHealthStore())
  }

  override func tearDown() {
    viewModel = nil
    super.tearDown()
  }

  // MARK: - Helper to call exportCSVData with a continuation

  private func exportCSV(
    results: [HKObjectType: [HKSample]],
    units: [HKObjectType: HKUnit] = [:]
  ) async -> URL {
    return await withUnsafeContinuation { continuation in
      viewModel.exportCSVData(results, continuation: continuation, unitsMapping: units)
    }
  }

  // MARK: - Header row

  func testCSVContainsHeaderRow() async throws {
    let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let sample = TestSampleFactory.makeSample(type: .stepCount, value: 100)

    let url = await exportCSV(
      results: [stepType: [sample]],
      units: [stepType: .count()])

    let content = try String(contentsOf: url, encoding: .utf8)
    let lines = content.components(separatedBy: "\n")
    XCTAssertTrue(lines[0].contains("Datetime"), "First line should contain header")
    XCTAssertTrue(lines[0].contains("Category"), "First line should contain Category header")
    XCTAssertTrue(lines[0].contains("Unit"), "First line should contain Unit header")
    XCTAssertTrue(lines[0].contains("Value"), "First line should contain Value header")

    try? FileManager.default.removeItem(at: url)
  }

  // MARK: - Row count

  func testCSVRowCountMatchesSamples() async throws {
    let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let samples = TestSampleFactory.makeGappedSamples(
      type: .stepCount, unit: .count(), count: 5, value: 100)

    let url = await exportCSV(
      results: [stepType: samples],
      units: [stepType: .count()])

    let content = try String(contentsOf: url, encoding: .utf8)
    let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
    // 1 header + 5 data rows
    XCTAssertEqual(lines.count, 6, "Should have 1 header + 5 data rows")

    try? FileManager.default.removeItem(at: url)
  }

  // MARK: - Empty results

  func testCSVWithEmptyResultsHasHeaderOnly() async throws {
    let url = await exportCSV(results: [:])

    let content = try String(contentsOf: url, encoding: .utf8)
    let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
    XCTAssertEqual(lines.count, 1, "Empty results should produce header-only CSV")

    try? FileManager.default.removeItem(at: url)
  }

  // MARK: - Fallback unit

  func testCSVUsesFallbackUnitWhenNoPreferredUnit() async throws {
    // Use bodyMass which is compatible with .gram() in fallbackUnits
    let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
    let sample = TestSampleFactory.makeSample(
      type: .bodyMass, unit: .gramUnit(with: .kilo), value: 75.0)

    // Pass no units -- should use fallback (gram)
    let url = await exportCSV(
      results: [bodyMassType: [sample]],
      units: [:])

    let content = try String(contentsOf: url, encoding: .utf8)
    let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
    // Should have header + data since gram is a valid fallback for bodyMass
    XCTAssertEqual(lines.count, 2, "Should produce data using fallback unit")

    try? FileManager.default.removeItem(at: url)
  }

  // MARK: - File creation

  func testCSVCreatesFileInTempDirectory() async throws {
    let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let sample = TestSampleFactory.makeSample(type: .stepCount, value: 1)

    let url = await exportCSV(
      results: [stepType: [sample]],
      units: [stepType: .count()])

    XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "CSV file should be created")
    XCTAssertTrue(url.lastPathComponent.hasSuffix(".csv"), "File should have .csv extension")

    try? FileManager.default.removeItem(at: url)
  }

  // MARK: - Multi-type export

  func testCSVWithMultipleTypesContainsAllRows() async throws {
    let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    let bpm = HKUnit.count().unitDivided(by: .minute())

    let stepSamples = TestSampleFactory.makeGappedSamples(
      type: .stepCount, unit: .count(), count: 3, value: 100)
    let hrSamples = TestSampleFactory.makeGappedSamples(
      type: .heartRate, unit: bpm, count: 2, value: 72)

    let url = await exportCSV(
      results: [stepType: stepSamples, hrType: hrSamples],
      units: [stepType: .count(), hrType: bpm])

    let content = try String(contentsOf: url, encoding: .utf8)
    let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
    // 1 header + 3 steps + 2 heart rate = 6
    XCTAssertEqual(lines.count, 6, "Should have rows for all types combined")

    try? FileManager.default.removeItem(at: url)
  }
}
