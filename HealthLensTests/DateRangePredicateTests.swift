import HealthKit
import XCTest

@testable import HealthLens

final class DateRangePredicateTests: XCTestCase {

  var viewModel: ContentViewModel!

  override func setUp() {
    super.setUp()
    viewModel = ContentViewModel(healthStore: MockHealthStore())
  }

  override func tearDown() {
    viewModel = nil
    super.tearDown()
  }

  // MARK: - Under 1 day range

  func testRangeUnderOneDayReturnsNil() {
    let now = Date()
    viewModel.startDate = now
    viewModel.endDate = now.addingTimeInterval(3600)  // 1 hour

    let predicate = viewModel.make_date_range_predicate()
    XCTAssertNil(predicate, "Range under 1 day should return nil predicate")
  }

  // MARK: - Exactly 1 day range

  func testRangeExactlyOneDayReturnsNil() {
    let now = Date()
    viewModel.startDate = now
    viewModel.endDate = now.addingTimeInterval(time_difference_large_enough)  // exactly 1 day

    let predicate = viewModel.make_date_range_predicate()
    XCTAssertNil(predicate, "Range exactly 1 day (<=) should return nil predicate")
  }

  // MARK: - Over 1 day range

  func testRangeOverOneDayReturnsPredicate() {
    let now = Date()
    viewModel.startDate = now
    viewModel.endDate = now.addingTimeInterval(time_difference_large_enough + 1)  // just over 1 day

    let predicate = viewModel.make_date_range_predicate()
    XCTAssertNotNil(predicate, "Range over 1 day should return a valid predicate")
  }

  func testSevenDayRangeReturnsPredicate() {
    let now = Date()
    viewModel.startDate = now
    viewModel.endDate = now.addingTimeInterval(7 * 24 * 60 * 60)

    let predicate = viewModel.make_date_range_predicate()
    XCTAssertNotNil(predicate, "7-day range should return a valid predicate")
  }

  // MARK: - Default dates (both set to now)

  func testDefaultDatesReturnNil() {
    // startDate and endDate default to Date() -- difference is ~0
    let predicate = viewModel.make_date_range_predicate()
    XCTAssertNil(predicate, "Default dates (both ~now) should return nil predicate")
  }

  // MARK: - Reversed dates

  func testReversedDatesStillReturnPredicate() {
    let now = Date()
    viewModel.startDate = now.addingTimeInterval(7 * 24 * 60 * 60)
    viewModel.endDate = now  // end before start

    let predicate = viewModel.make_date_range_predicate()
    // abs() is used, so reversed dates with > 1 day difference still produce a predicate
    XCTAssertNotNil(predicate, "Reversed dates with > 1 day range should still return predicate")
  }

  // MARK: - Same date returns nil

  func testSameDateReturnsNil() {
    let date = Date(timeIntervalSince1970: 1_000_000)
    viewModel.startDate = date
    viewModel.endDate = date

    let predicate = viewModel.make_date_range_predicate()
    XCTAssertNil(predicate, "Same start and end date should return nil")
  }
}
