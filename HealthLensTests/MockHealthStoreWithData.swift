import HealthKit
@testable import HealthLens

/// Configurable mock HealthStore that returns pre-configured samples and units
class MockHealthStoreWithData: HealthStoreProtocol {
  var sampleData: [HKSampleType: [HKSample]] = [:]
  var unitData: [HKQuantityType: HKUnit] = [:]
  var authorizationRequests: [(Set<HKSampleType>?, Set<HKObjectType>?)] = []

  init(
    samples: [HKSampleType: [HKSample]] = [:],
    units: [HKQuantityType: HKUnit] = [:]
  ) {
    self.sampleData = samples
    self.unitData = units
  }

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
    completion(unitData, nil)
  }

  func executeSampleQuery(
    sampleType: HKSampleType, predicate: NSPredicate?, limit: Int,
    sortDescriptors: [NSSortDescriptor]?,
    resultsHandler: @escaping (HKSampleQuery, [HKSample]?, Error?) -> Void
  ) {
    let query = HKSampleQuery(
      sampleType: sampleType, predicate: predicate, limit: limit,
      sortDescriptors: sortDescriptors, resultsHandler: resultsHandler)
    let samples = sampleData[sampleType] ?? []
    resultsHandler(query, samples, nil)
  }

  func isHealthDataAvailable() -> Bool {
    return true
  }
}
