import HealthKit
import XCTest

@testable import HealthLens

/// Core integration smoke tests for the HealthLens export pipeline
final class HealthLensTests: XCTestCase {

  // MARK: - Authorization flow

  func testHealthStoreAuthorizationRequested() {
    let mockStore = MockHealthStore()
    let viewModel = ContentViewModel(healthStore: mockStore)

    let typeToSelect = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    viewModel.toggleTypeIdentifier(.stepCount)

    let expectation = self.expectation(description: "Authorization Requested")

    Task {
      _ = await viewModel.asyncExportHealthData()

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
    viewModel.selectedExportFormat = .csv
    viewModel.toggleTypeIdentifier(.stepCount)

    let expectation = self.expectation(description: "CSV Export")

    Task {
      let url = await viewModel.asyncExportHealthData()

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
    viewModel.selectedExportFormat = .xlsx
    viewModel.toggleTypeIdentifier(.stepCount)

    let expectation = self.expectation(description: "XLSX Export")

    Task {
      let url = await viewModel.asyncExportHealthData()

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

    viewModel.toggleTypeIdentifier(.stepCount)
    viewModel.toggleTypeIdentifier(.heartRate)
    XCTAssertEqual(viewModel.selectedQuantityTypes.count, 2)

    viewModel.clearExportQueue()
    XCTAssertTrue(viewModel.selectedQuantityTypes.isEmpty)
  }
}
