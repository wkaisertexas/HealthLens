import HealthKit
import XCTest

@testable import HealthLens

/// Integration tests for XLSX export stability with real data.
/// Tests for segfaults and crashes when using libxlsxwriter with real health data.
/// Requires self-hosted runner with real HealthKit data.
final class XLSXStabilityTests: XCTestCase {

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

  // MARK: - Basic XLSX export with real data

  func testXLSXExportWithRealStepCount() {
    viewModel.selectedExportFormat = .xlsx
    viewModel.toggleTypeIdentifier(.stepCount)

    let expectation = self.expectation(description: "XLSX Step Count")

    Task {
      let url = await viewModel.asyncExportHealthData()

      XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
      XCTAssertTrue(url.lastPathComponent.hasSuffix(".xlsx"))

      // Verify it's a valid ZIP (XLSX is ZIP-based)
      if let data = try? Data(contentsOf: url), data.count >= 2 {
        XCTAssertEqual(data[0], 0x50, "Should be valid XLSX (PK header)")
        XCTAssertEqual(data[1], 0x4B, "Should be valid XLSX (PK header)")
      }

      try? FileManager.default.removeItem(at: url)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 30.0, handler: nil)
  }

  // MARK: - Multi-type XLSX export

  func testXLSXExportWithMultipleRealTypes() {
    viewModel.selectedExportFormat = .xlsx
    viewModel.toggleTypeIdentifier(.stepCount)
    viewModel.toggleTypeIdentifier(.heartRate)
    viewModel.toggleTypeIdentifier(.activeEnergyBurned)
    viewModel.toggleTypeIdentifier(.distanceWalkingRunning)

    let expectation = self.expectation(description: "XLSX Multi-Type")

    Task {
      let url = await viewModel.asyncExportHealthData()

      XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

      let fileSize =
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int ?? 0
      XCTAssertGreaterThan(fileSize, 0, "XLSX file should not be empty")

      try? FileManager.default.removeItem(at: url)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 60.0, handler: nil)
  }

  // MARK: - Repeated exports (stress test for memory leaks / segfaults)

  func testRepeatedXLSXExportsWithRealData() {
    viewModel.selectedExportFormat = .xlsx
    viewModel.toggleTypeIdentifier(.stepCount)

    let expectation = self.expectation(description: "XLSX Repeated Exports")

    Task {
      for i in 0..<10 {
        let url = await viewModel.asyncExportHealthData()

        XCTAssertTrue(
          FileManager.default.fileExists(atPath: url.path),
          "Export \(i) should produce a file")

        try? FileManager.default.removeItem(at: url)
      }

      expectation.fulfill()
    }

    waitForExpectations(timeout: 120.0, handler: nil)
  }

  // MARK: - All active types XLSX export

  func testXLSXExportWithAllActiveTypes() {
    viewModel.selectedExportFormat = .xlsx

    // Select all active quantity types from category groups
    for group in viewModel.categoryGroups {
      for identifier in group.quantities {
        viewModel.toggleTypeIdentifier(identifier)
      }
    }

    let expectation = self.expectation(description: "XLSX All Types")

    Task {
      let url = await viewModel.asyncExportHealthData()

      XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

      try? FileManager.default.removeItem(at: url)
      expectation.fulfill()
    }

    // Longer timeout for exporting all types
    waitForExpectations(timeout: 180.0, handler: nil)
  }
}
