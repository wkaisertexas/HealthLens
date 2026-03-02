import HealthKit

/// Helpers to generate HKQuantitySample arrays for testing
enum TestSampleFactory {

  /// Creates consecutive samples where end of one equals start of next
  static func makeConsecutiveSamples(
    type: HKQuantityTypeIdentifier = .stepCount,
    unit: HKUnit = .count(),
    count: Int,
    startDate: Date = Date(timeIntervalSince1970: 1_000_000),
    intervalSeconds: TimeInterval = 1.0,
    value: Double = 10.0
  ) -> [HKQuantitySample] {
    let quantityType = HKQuantityType.quantityType(forIdentifier: type)!
    var samples: [HKQuantitySample] = []
    var currentStart = startDate

    for _ in 0..<count {
      let end = currentStart.addingTimeInterval(intervalSeconds)
      let quantity = HKQuantity(unit: unit, doubleValue: value)
      let sample = HKQuantitySample(
        type: quantityType, quantity: quantity, start: currentStart, end: end)
      samples.append(sample)
      currentStart = end
    }

    return samples
  }

  /// Creates samples with a gap between each one
  static func makeGappedSamples(
    type: HKQuantityTypeIdentifier = .stepCount,
    unit: HKUnit = .count(),
    count: Int,
    startDate: Date = Date(timeIntervalSince1970: 1_000_000),
    durationSeconds: TimeInterval = 60.0,
    gapSeconds: TimeInterval = 300.0,
    value: Double = 100.0
  ) -> [HKQuantitySample] {
    let quantityType = HKQuantityType.quantityType(forIdentifier: type)!
    var samples: [HKQuantitySample] = []
    var currentStart = startDate

    for _ in 0..<count {
      let end = currentStart.addingTimeInterval(durationSeconds)
      let quantity = HKQuantity(unit: unit, doubleValue: value)
      let sample = HKQuantitySample(
        type: quantityType, quantity: quantity, start: currentStart, end: end)
      samples.append(sample)
      currentStart = end.addingTimeInterval(gapSeconds)
    }

    return samples
  }

  /// Creates a single sample
  static func makeSample(
    type: HKQuantityTypeIdentifier = .stepCount,
    unit: HKUnit = .count(),
    value: Double = 42.0,
    start: Date = Date(timeIntervalSince1970: 1_000_000),
    end: Date? = nil
  ) -> HKQuantitySample {
    let quantityType = HKQuantityType.quantityType(forIdentifier: type)!
    let quantity = HKQuantity(unit: unit, doubleValue: value)
    return HKQuantitySample(
      type: quantityType, quantity: quantity,
      start: start, end: end ?? start.addingTimeInterval(60))
  }

  /// Creates samples with varying values
  static func makeSamplesWithValues(
    type: HKQuantityTypeIdentifier = .heartRate,
    unit: HKUnit = HKUnit.count().unitDivided(by: .minute()),
    values: [Double],
    startDate: Date = Date(timeIntervalSince1970: 1_000_000),
    durationSeconds: TimeInterval = 60.0,
    consecutive: Bool = true
  ) -> [HKQuantitySample] {
    let quantityType = HKQuantityType.quantityType(forIdentifier: type)!
    var samples: [HKQuantitySample] = []
    var currentStart = startDate

    for value in values {
      let end = currentStart.addingTimeInterval(durationSeconds)
      let quantity = HKQuantity(unit: unit, doubleValue: value)
      let sample = HKQuantitySample(
        type: quantityType, quantity: quantity, start: currentStart, end: end)
      samples.append(sample)
      currentStart = consecutive ? end : end.addingTimeInterval(300)
    }

    return samples
  }
}
