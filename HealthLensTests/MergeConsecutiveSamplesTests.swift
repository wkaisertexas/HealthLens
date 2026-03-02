import HealthKit
import XCTest

@testable import HealthLens

final class MergeConsecutiveSamplesTests: XCTestCase {

  var viewModel: ContentViewModel!

  override func setUp() {
    super.setUp()
    viewModel = ContentViewModel(healthStore: MockHealthStore())
  }

  override func tearDown() {
    viewModel = nil
    super.tearDown()
  }

  // MARK: - Empty and single input

  func testEmptyInputReturnsEmpty() {
    let type = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let result = viewModel.mergeConsecutiveSamples([], for: type, unit: .count())
    XCTAssertTrue(result.isEmpty, "Empty input should produce empty output")
  }

  func testSingleSampleReturnsSingleSample() {
    let type = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let sample = TestSampleFactory.makeSample(type: .stepCount, value: 100)
    let result = viewModel.mergeConsecutiveSamples([sample], for: type, unit: .count())
    XCTAssertEqual(result.count, 1, "Single sample should produce single output")
  }

  // MARK: - Cumulative type merging (stepCount is cumulative)

  func testConsecutiveCumulativeSamplesAreSummed() {
    let type = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    // 5 consecutive 1-second samples, each with value 10
    let samples = TestSampleFactory.makeConsecutiveSamples(
      type: .stepCount, unit: .count(), count: 5, value: 10)

    let result = viewModel.mergeConsecutiveSamples(samples, for: type, unit: .count())

    XCTAssertEqual(result.count, 1, "All consecutive samples should merge into one")
    let merged = result.first as! HKQuantitySample
    // Cumulative: sum of all values = 5 * 10 = 50
    XCTAssertEqual(
      merged.quantity.doubleValue(for: .count()), 50.0,
      "Cumulative merge should sum values")
  }

  func testConsecutiveCumulativeSamplesPreserveDateRange() {
    let type = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let startDate = Date(timeIntervalSince1970: 1_000_000)
    let samples = TestSampleFactory.makeConsecutiveSamples(
      type: .stepCount, unit: .count(), count: 10, startDate: startDate,
      intervalSeconds: 1.0, value: 5)

    let result = viewModel.mergeConsecutiveSamples(samples, for: type, unit: .count())
    let merged = result.first as! HKQuantitySample

    XCTAssertEqual(
      merged.startDate, startDate,
      "Merged sample should start at first sample's start date")
    XCTAssertEqual(
      merged.endDate, startDate.addingTimeInterval(10.0),
      "Merged sample should end at last sample's end date")
  }

  // MARK: - Discrete type merging (heartRate is discrete)

  func testConsecutiveDiscreteSamplesAreWeightedAverage() {
    let type = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    let bpm = HKUnit.count().unitDivided(by: .minute())
    // 3 consecutive samples with equal duration, values 60, 80, 100
    let samples = TestSampleFactory.makeSamplesWithValues(
      type: .heartRate, unit: bpm, values: [60, 80, 100],
      durationSeconds: 60.0, consecutive: true)

    let result = viewModel.mergeConsecutiveSamples(samples, for: type, unit: bpm)

    XCTAssertEqual(result.count, 1, "All consecutive discrete samples should merge")
    let merged = result.first as! HKQuantitySample
    // Weighted average with equal durations = simple average = (60+80+100)/3 = 80
    let mergedValue = merged.quantity.doubleValue(for: bpm)
    XCTAssertEqual(mergedValue, 80.0, accuracy: 0.01, "Discrete merge should weighted-average values")
  }

  // MARK: - Mixed consecutive and gapped

  func testMixedConsecutiveAndGappedSamples() {
    let type = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let startDate = Date(timeIntervalSince1970: 1_000_000)

    // Create 3 consecutive, then a gap, then 2 consecutive
    var samples: [HKQuantitySample] = []
    // Batch 1: 3 consecutive
    var current = startDate
    for _ in 0..<3 {
      let end = current.addingTimeInterval(1.0)
      samples.append(
        TestSampleFactory.makeSample(type: .stepCount, value: 10, start: current, end: end))
      current = end
    }
    // Gap of 60 seconds
    current = current.addingTimeInterval(60)
    // Batch 2: 2 consecutive
    for _ in 0..<2 {
      let end = current.addingTimeInterval(1.0)
      samples.append(
        TestSampleFactory.makeSample(type: .stepCount, value: 20, start: current, end: end))
      current = end
    }

    let result = viewModel.mergeConsecutiveSamples(samples, for: type, unit: .count())

    XCTAssertEqual(result.count, 2, "Should produce 2 groups: 3 consecutive + 2 consecutive")
    let first = result[0] as! HKQuantitySample
    let second = result[1] as! HKQuantitySample
    XCTAssertEqual(
      first.quantity.doubleValue(for: .count()), 30.0,
      "First batch: 3 * 10 = 30")
    XCTAssertEqual(
      second.quantity.doubleValue(for: .count()), 40.0,
      "Second batch: 2 * 20 = 40")
  }

  // MARK: - All gapped samples stay separate

  func testAllGappedSamplesRemainSeparate() {
    let type = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let samples = TestSampleFactory.makeGappedSamples(
      type: .stepCount, unit: .count(), count: 5, gapSeconds: 300, value: 100)

    let result = viewModel.mergeConsecutiveSamples(samples, for: type, unit: .count())

    XCTAssertEqual(result.count, 5, "Gapped samples should not merge")
  }

  // MARK: - Fallback unit

  func testMergeUseFallbackUnitWhenNilProvided() {
    let type = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let samples = TestSampleFactory.makeConsecutiveSamples(
      type: .stepCount, unit: .count(), count: 3, value: 10)

    // Pass nil for unit -- should use fallback
    let result = viewModel.mergeConsecutiveSamples(samples, for: type, unit: nil)

    XCTAssertEqual(result.count, 1, "Should still merge even with nil unit")
    let merged = result.first as! HKQuantitySample
    // Should still produce a valid quantity
    XCTAssertEqual(
      merged.quantity.doubleValue(for: .count()), 30.0,
      "Fallback unit should produce correct sum")
  }

  // MARK: - Time in daylight regression (todo item 1)

  func testOneSecondIntervalSamplesGetMergedToMeaningfulDuration() {
    let type = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    // Simulate the "time in daylight" issue: many 1-second samples
    let samples = TestSampleFactory.makeConsecutiveSamples(
      type: .stepCount, unit: .count(), count: 100,
      intervalSeconds: 1.0, value: 1)

    let result = viewModel.mergeConsecutiveSamples(samples, for: type, unit: .count())

    XCTAssertEqual(result.count, 1, "100 consecutive 1-sec samples should merge into 1")
    let merged = result.first as! HKQuantitySample
    let duration = merged.endDate.timeIntervalSince(merged.startDate)
    XCTAssertEqual(duration, 100.0, accuracy: 0.1, "Merged duration should be 100 seconds")
    XCTAssertEqual(
      merged.quantity.doubleValue(for: .count()), 100.0,
      "Sum should be 100")
  }
}
