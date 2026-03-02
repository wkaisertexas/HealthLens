import XCTest

@testable import HealthLens

final class SanitizationTests: XCTestCase {

  var viewModel: ContentViewModel!

  override func setUp() {
    super.setUp()
    viewModel = ContentViewModel(healthStore: MockHealthStore())
  }

  override func tearDown() {
    viewModel = nil
    super.tearDown()
  }

  func testNormalStringUnchanged() {
    let input = "Hello World"
    let result = viewModel.sanitizeForCSV(input)
    XCTAssertEqual(result, input, "Normal string should not be modified")
  }

  func testStringWithNewlineGetsQuoted() {
    let input = "line1\nline2"
    let result = viewModel.sanitizeForCSV(input)
    XCTAssertTrue(result.hasPrefix("\""), "String with newline should be wrapped in quotes")
    XCTAssertTrue(result.hasSuffix("\""), "String with newline should be wrapped in quotes")
    XCTAssertTrue(result.contains("\n"), "Newline should be preserved inside quotes")
  }

  func testStringWithCommaGetsQuoted() {
    let input = "value1,value2"
    let result = viewModel.sanitizeForCSV(input)
    XCTAssertEqual(result, "\"value1,value2\"", "Commas should trigger quoting")
  }

  func testStringWithDoubleQuoteGetsEscaped() {
    let input = "say \"hello\""
    let result = viewModel.sanitizeForCSV(input)
    // Double quotes get doubled, then the result contains a quote so it gets wrapped
    XCTAssertTrue(result.contains("\"\""), "Double quotes should be escaped to double-double quotes")
  }

  func testEmptyStringUnchanged() {
    let input = ""
    let result = viewModel.sanitizeForCSV(input)
    XCTAssertEqual(result, "", "Empty string should remain empty")
  }

  func testCombinedSpecialCharacters() {
    let input = "has,comma\nand \"quotes\""
    let result = viewModel.sanitizeForCSV(input)
    XCTAssertTrue(result.hasPrefix("\""), "Combined special chars should be quoted")
    XCTAssertTrue(result.hasSuffix("\""), "Combined special chars should be quoted")
    // Original quotes should be escaped
    XCTAssertTrue(
      result.contains("\"\"quotes\"\""),
      "Embedded quotes should be escaped within quoted string")
  }

  func testNumericStringUnchanged() {
    let input = "12345.67"
    let result = viewModel.sanitizeForCSV(input)
    XCTAssertEqual(result, input, "Numeric string without special chars should not change")
  }
}
