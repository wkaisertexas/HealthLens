import HealthKit
import XCTest

@testable import HealthLens

/// for testing, use healthkit's testing framework in swift: https://github.com/StanfordBDHG/XCTHealthKit
final class HealthLensTests: XCTestCase {

  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  func testCSVSanitization() throws {
    let viewModel = ContentViewModel()

    let normal_string = "asdfabasdfasdf"
    let abnormal_string = "asdfabasdfasdf\n"

    XCTAssertEqual(
      viewModel.sanitizeForCSV(normal_string).count, normal_string.count,
      "sanitization should not have changed width")
    XCTAssertNotEqual(
      viewModel.sanitizeForCSV(abnormal_string).count, abnormal_string.count,
      "width should have changed")
  }

  func testPerformanceExample() throws {
    // This is an example of a performance test case.
    self.measure {
      // Put the code you want to measure the time of here.
      // we are going to measure the collecting of test information

    }
  }

  func testHealthStoreInteraction() {
    let mockStore = MockHealthStore()
    let viewModel = ContentViewModel(healthStore: mockStore)

    // Simulate an action that requires authorization
    let typeToSelect = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    viewModel.toggleTypeIdentifier(.stepCount)

    let expectation = self.expectation(description: "Authorization Requested")

    // We can't easily wait for the async task inside exportHealthData without modifying it to return something or be awaitable.
    // However, we can check if the mock store recorded the request if we call the method.
    // But exportHealthData is called within an async task in UI usually.
    // Here we can call it directly if we mock the continuation? No, it takes a continuation.

    // Let's call asyncExportHealthData
    Task {
      _ = await viewModel.asyncExportHealthData()

      XCTAssertEqual(mockStore.authorizationRequests.count, 1)
      let (share, read) = mockStore.authorizationRequests.first!
      XCTAssertNil(share)
      XCTAssertTrue(read?.contains(typeToSelect) ?? false)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 1.0, handler: nil)
  }
}

class MockHealthStore: HealthStoreProtocol {
  var authorizationRequests: [(Set<HKSampleType>?, Set<HKObjectType>?)] = []

  func requestAuthorization(
    toShare typesToShare: Set<HKSampleType>?, read typesToRead: Set<HKObjectType>?,
    completion: @escaping (Bool, Error?) -> Void
  ) {
    authorizationRequests.append((typesToShare, typesToRead))
    completion(true, nil)
  }

  func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
    return .notDetermined
  }

  func preferredUnits(
    for quantityTypes: Set<HKQuantityType>,
    completion: @escaping ([HKQuantityType: HKUnit], Error?) -> Void
  ) {
    completion([:], nil)
  }

  func executeSampleQuery(
    sampleType: HKSampleType, predicate: NSPredicate?, limit: Int,
    sortDescriptors: [NSSortDescriptor]?,
    resultsHandler: @escaping (HKSampleQuery, [HKSample]?, Error?) -> Void
  ) {
    // Trigger the results handler immediately with empty results or mock results
    let query = HKSampleQuery(
      sampleType: sampleType, predicate: predicate, limit: limit, sortDescriptors: sortDescriptors,
      resultsHandler: resultsHandler)
    resultsHandler(query, [], nil)
  }

  func isHealthDataAvailable() -> Bool {
    return true
  }
}
