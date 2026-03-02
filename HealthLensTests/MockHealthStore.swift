import HealthKit
@testable import HealthLens

/// Mock HealthStore that returns empty results and tracks authorization calls
class MockHealthStore: HealthStoreProtocol {
  var authorizationRequests: [(Set<HKSampleType>?, Set<HKObjectType>?)] = []
  var authorizationStatusToReturn: HKAuthorizationStatus = .notDetermined
  var isHealthDataAvailableResult = true

  func requestAuthorization(
    toShare typesToShare: Set<HKSampleType>?, read typesToRead: Set<HKObjectType>?,
    completion: @escaping (Bool, Error?) -> Void
  ) {
    authorizationRequests.append((typesToShare, typesToRead))
    completion(true, nil)
  }

  func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
    return authorizationStatusToReturn
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
    let query = HKSampleQuery(
      sampleType: sampleType, predicate: predicate, limit: limit,
      sortDescriptors: sortDescriptors, resultsHandler: resultsHandler)
    resultsHandler(query, [], nil)
  }

  func isHealthDataAvailable() -> Bool {
    return isHealthDataAvailableResult
  }
}
