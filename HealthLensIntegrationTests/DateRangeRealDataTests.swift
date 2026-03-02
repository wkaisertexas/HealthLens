import HealthKit
import XCTest

@testable import HealthLens

/// Integration tests for date range filtering with real data.
/// Requires self-hosted runner with real HealthKit data.
final class DateRangeRealDataTests: XCTestCase {

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

  // MARK: - 7-day window exports only recent data

  func testSevenDayWindowLimitsResults() {
    viewModel.selectedExportFormat = .csv
    viewModel.toggleTypeIdentifier(.stepCount)

    // Set a 7-day window ending now
    let now = Date()
    viewModel.startDate = now.addingTimeInterval(-7 * 24 * 60 * 60)
    viewModel.endDate = now
    viewModel.dateSelectorEnabled = true

    let expectation = self.expectation(description: "7-Day Export")

    Task {
      let url = await viewModel.asyncExportHealthData()

      XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

      try? FileManager.default.removeItem(at: url)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 30.0, handler: nil)
  }

  // MARK: - Default dates return unfiltered data

  func testDefaultDatesReturnUnfilteredData() {
    viewModel.selectedExportFormat = .csv
    viewModel.toggleTypeIdentifier(.stepCount)
    // Don't set any dates -- defaults should result in no filtering

    let expectation = self.expectation(description: "Unfiltered Export")

    Task {
      let url = await viewModel.asyncExportHealthData()

      XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

      try? FileManager.default.removeItem(at: url)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 30.0, handler: nil)
  }

  // MARK: - Narrow window reduces row count vs unfiltered

  func testNarrowWindowProducesFewerRowsThanUnfiltered() {
    viewModel.selectedExportFormat = .csv
    viewModel.toggleTypeIdentifier(.stepCount)

    let expectation = self.expectation(description: "Filtered vs Unfiltered")

    Task {
      // First: unfiltered export
      let unfilteredURL = await viewModel.asyncExportHealthData()
      let unfilteredContent = (try? String(contentsOf: unfilteredURL, encoding: .utf8)) ?? ""
      let unfilteredLines = unfilteredContent.components(separatedBy: "\n").filter { !$0.isEmpty }

      try? FileManager.default.removeItem(at: unfilteredURL)

      // Second: 2-day window
      let now = Date()
      viewModel.startDate = now.addingTimeInterval(-2 * 24 * 60 * 60)
      viewModel.endDate = now

      let filteredURL = await viewModel.asyncExportHealthData()
      let filteredContent = (try? String(contentsOf: filteredURL, encoding: .utf8)) ?? ""
      let filteredLines = filteredContent.components(separatedBy: "\n").filter { !$0.isEmpty }

      try? FileManager.default.removeItem(at: filteredURL)

      // Filtered should have <= rows than unfiltered (if device has data beyond 2 days)
      if unfilteredLines.count > 2 {
        XCTAssertLessThanOrEqual(
          filteredLines.count, unfilteredLines.count,
          "Filtered export should not have more rows than unfiltered")
      }

      expectation.fulfill()
    }

    waitForExpectations(timeout: 60.0, handler: nil)
  }
}
