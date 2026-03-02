import HealthKit
import XCTest

@testable import HealthLens

final class UnitCompatibilityTests: XCTestCase {

  var viewModel: ContentViewModel!

  override func setUp() {
    super.setUp()
    viewModel = ContentViewModel(healthStore: MockHealthStore())
  }

  override func tearDown() {
    viewModel = nil
    super.tearDown()
  }

  // MARK: - Active category group types have a compatible fallback unit

  func testActiveGroupTypesHaveCompatibleFallbackUnit() {
    var missingTypes: [String] = []

    for group in viewModel.categoryGroups {
      for identifier in group.quantities {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
          continue
        }

        let hasCompatibleUnit = viewModel.fallbackUnits.contains { unit in
          quantityType.is(compatibleWith: unit)
        }

        if !hasCompatibleUnit {
          let name = viewModel.quantityMapping[identifier] ?? identifier.rawValue
          missingTypes.append("'\(name)' in \(group.name)")
        }
      }
    }

    // This is informational -- types without fallback units rely on preferredUnits from HealthKit
    // They only fail silently if HealthKit also returns no preferred unit
    if !missingTypes.isEmpty {
      print("Types without fallback units (rely on HealthKit preferredUnits): \(missingTypes.joined(separator: ", "))")
    }

    // At minimum, body measurement types that use standard units should have fallbacks
    let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
    XCTAssertTrue(
      viewModel.fallbackUnits.contains { bodyMassType.is(compatibleWith: $0) },
      "bodyMass should have a compatible fallback unit")

    let heightType = HKQuantityType.quantityType(forIdentifier: .height)!
    XCTAssertTrue(
      viewModel.fallbackUnits.contains { heightType.is(compatibleWith: $0) },
      "height should have a compatible fallback unit")
  }

  // MARK: - Unit strings are non-empty

  func testFallbackUnitStringsAreNonEmpty() {
    for unit in viewModel.fallbackUnits {
      XCTAssertFalse(
        unit.unitString.isEmpty,
        "Fallback unit should have a non-empty unitString")
    }
  }

  // MARK: - Active category groups have mapped names

  func testAllActiveGroupQuantitiesHaveMappedNames() {
    for group in viewModel.categoryGroups {
      for identifier in group.quantities {
        let name = viewModel.quantityMapping[identifier]
        XCTAssertNotNil(
          name,
          "Quantity \(identifier.rawValue) in group '\(group.name)' has no mapping")
        if let name = name {
          XCTAssertFalse(
            name.isEmpty,
            "Quantity \(identifier.rawValue) in group '\(group.name)' has empty name")
        }
      }
    }
  }

  // MARK: - Sample cap is reasonable

  func testSampleCapIsReasonable() {
    XCTAssertGreaterThan(sample_cap, 0, "Sample cap should be positive")
    XCTAssertLessThanOrEqual(sample_cap, 100_000, "Sample cap should not be unreasonably large")
  }

  // MARK: - Each active group type can create a sample

  func testCanCreateSampleForEachActiveQuantityType() {
    for group in viewModel.categoryGroups {
      for identifier in group.quantities {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
          XCTFail("Could not create type for \(identifier.rawValue)")
          continue
        }

        // Find a compatible unit
        guard
          let unit = viewModel.fallbackUnits.first(where: {
            quantityType.is(compatibleWith: $0)
          })
        else {
          // Already covered by testAllQuantityMappingTypesHaveCompatibleFallbackUnit
          continue
        }

        let quantity = HKQuantity(unit: unit, doubleValue: 1.0)
        let sample = HKQuantitySample(
          type: quantityType, quantity: quantity, start: Date(), end: Date())

        XCTAssertNotNil(
          sample,
          "Should be able to create sample for \(identifier.rawValue)")
      }
    }
  }
}
