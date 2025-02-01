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

}
