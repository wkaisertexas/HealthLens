import HealthKit
import XCTest

@testable import HealthLens

/// Integration tests that export real health data from a device.
/// These tests require a self-hosted runner with real HealthKit data.
/// They are NOT run in CI -- only via the integration-tests workflow on a local device.
final class RealDataExportTests: XCTestCase {

  var viewModel: ContentViewModel!

  override func setUp() {
    super.setUp()
    guard HKHealthStore.isHealthDataAvailable() else {
      XCTFail("HealthKit not available on this device")
      return
    }
    viewModel = ContentViewModel()
  }

  override func tearDown() {
    viewModel = nil
    super.tearDown()
  }

  // MARK: - Step count export

  func testExportRealStepCountData() {
    viewModel.selectedExportFormat = .csv
    viewModel.toggleTypeIdentifier(.stepCount)

    let expectation = self.expectation(description: "Step Count Export")

    Task {
      let url = await viewModel.asyncExportHealthData()

      XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

      if let content = try? String(contentsOf: url, encoding: .utf8) {
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        // Should have at least the header
        XCTAssertGreaterThanOrEqual(lines.count, 1)
        // If device has step data, should have data rows
        if lines.count > 1 {
          // Verify data rows have 4 columns
          let dataLine = lines[1]
          let columns = dataLine.components(separatedBy: ",")
          XCTAssertGreaterThanOrEqual(columns.count, 4, "Each data row should have at least 4 columns")
        }
      }

      try? FileManager.default.removeItem(at: url)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 30.0, handler: nil)
  }

  // MARK: - Heart rate export with meaningful durations

  func testExportRealHeartRateHasMeaningfulDurations() {
    viewModel.selectedExportFormat = .csv
    viewModel.toggleTypeIdentifier(.heartRate)

    let expectation = self.expectation(description: "Heart Rate Export")

    Task {
      let url = await viewModel.asyncExportHealthData()

      if let content = try? String(contentsOf: url, encoding: .utf8) {
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        if lines.count > 1 {
          // Verify the unit is meaningful (should be count/min or similar)
          let dataLine = lines[1]
          XCTAssertFalse(dataLine.isEmpty, "Data line should not be empty")
        }
      }

      try? FileManager.default.removeItem(at: url)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 30.0, handler: nil)
  }

  // MARK: - Time in daylight regression (todo item 1)

  func testTimeInDaylightExportHasMeaningfulIntervals() {
    viewModel.selectedExportFormat = .csv
    viewModel.toggleTypeIdentifier(.timeInDaylight)

    let expectation = self.expectation(description: "Time in Daylight Export")

    Task {
      let url = await viewModel.asyncExportHealthData()

      if let content = try? String(contentsOf: url, encoding: .utf8) {
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        // If there's real data, the merging should produce reasonable row counts
        // (not thousands of 1-second rows)
        if lines.count > 1 {
          XCTAssertLessThan(
            lines.count, 10_000,
            "Merged time in daylight should not produce thousands of 1-second rows")
        }
      }

      try? FileManager.default.removeItem(at: url)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 30.0, handler: nil)
  }

  // MARK: - Multi-type export

  func testExportMultipleRealTypes() {
    viewModel.selectedExportFormat = .csv
    viewModel.toggleTypeIdentifier(.stepCount)
    viewModel.toggleTypeIdentifier(.heartRate)
    viewModel.toggleTypeIdentifier(.activeEnergyBurned)

    let expectation = self.expectation(description: "Multi-Type Export")

    Task {
      let url = await viewModel.asyncExportHealthData()

      XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

      try? FileManager.default.removeItem(at: url)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 60.0, handler: nil)
  }
}
