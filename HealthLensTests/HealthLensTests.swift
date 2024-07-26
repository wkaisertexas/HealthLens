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

  func testGeneratePreferredUnitType() async throws {
    let viewModel = ContentViewModel()

    // making a sample list of things
    viewModel.selectedQuantityTypes = [
      .activeEnergyBurned,
      .appleMoveTime,
      .appleStandTime,
      .bodyMass,
    ]

    // note: I must be authorized to get the things
    let prefferedTypes = try! await viewModel.getPreferredUnitType()

    // check to make sure this is approximately the sample length
    let beforeKeys = viewModel.selectedQuantityTypes.count
    let afterKeys = prefferedTypes.count

    // checks
    XCTAssertEqual(beforeKeys, afterKeys, "There should be a preferred type for each key")
  }

  func testPerformanceExample() throws {
    // This is an example of a performance test case.
    self.measure {
      // Put the code you want to measure the time of here.
      // we are going to measure the collecting of test information

    }
  }

}
