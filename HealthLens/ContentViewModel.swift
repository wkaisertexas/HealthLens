import HealthKit
import StoreKit
import SwiftUI
import libxlsxwriter

let review_wait_time = 5  //< Wait time in seconds after export
let export_count = 2  //< How many unique exports must be asked for before a review
let categories_exported = 10  //< Categories exported before a review is asked for
let defaultExportFormat: ExportFormat = .xlsx

/// Contains all of the data to store the necessary health records
class ContentViewModel: ObservableObject {
  private let healthStore = HKHealthStore()
  typealias ExportContinuation = UnsafeContinuation<String, Never>
  
  var headers: [String] {
    return [
      String(localized: "Date"),
      String(localized: "Time"),
      String(localized: "Unit"),
      String(localized: "Value"),
    ]
  }
  
  
  private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    return formatter
  }()

  // -MARK: Stateful representations of the input form
  public var shareTarget: ExportFile

  @Environment(\.requestReview) var requestReview
  @AppStorage("timesExported") public var timesExported = 0
  @AppStorage("categoriesExported") public var categoriesExported = 0
  @AppStorage("lastRequested") public var lastRequested = "0.0.0"

  // Date range state
  @Published public var dateSelectorEnabled = false
  @Published public var startDate = Date()
  @Published public var endDate = Date()
  public var currentDate = Date()  // date is simply set to the current date without any changes

  public func suggestedFileName() -> String {
    let result =
      selectedQuantityTypes
      .map { quantityMapping[$0]! }
      .sorted()
      .joined(separator: "-")
      .replacingOccurrences(of: " ", with: ".").lowercased()

    return "\(result).csv"
  }

  public init() {
    // setting up share target
    shareTarget = ExportFile()
    shareTarget.collectData = asyncExportHealthData
    shareTarget.fileName = suggestedFileName

    // converting HKQuantityTypeIdentifier and HKCategoryTypeIdentifier to HKQuantityType and HKCategoryType
    quantityMapping.keys.forEach({
      if let obj = HKObjectType.quantityType(forIdentifier: $0) {
        quantityTypes.append(obj)
      }
    })

    categoryMapping.keys.forEach({
      if let obj = HKObjectType.categoryType(forIdentifier: $0) {
        categoryTypes.append(obj)
      }
    })
  }

  // -MARK: Health Kit Constants
  let categoryGroups = [
    bodyMeasurementsGroup,
    fitnessGroup,
    hearingHealthGroup,
    heartGroup,
    mobilityGroup,
    //        reproductiveHealthGroup,
    respiratoryGroup,
    //        sleepGroup,
    // symptomsGroup,
    vitalSignsGroup,
    otherGroup,
    respiratoryGroup,

    // TODO: Add a way to export this commented out categories
    // reproductiveHealthGroup,
    // sleepGroup,
    // symptomsGroup,
    // nutritionGroup,
  ]

  public let quantityMapping: [HKQuantityTypeIdentifier: String] = [
    // Body Measurements
    .bodyMass: "Weight",
    .bodyMassIndex: "Body Mass Index (BMI)",
    .leanBodyMass: "Lean Body Mass",
    .height: "Height",
    .waistCircumference: "Waist Circumference",
    .bodyFatPercentage: "Body Fat Percentage",
    .electrodermalActivity: "Electrodermal Activity",

    // Fitness
    .activeEnergyBurned: "Active Energy Burned",
    .appleExerciseTime: "Exercise Time",
    .appleMoveTime: "Move Time",
    .appleStandTime: "Stand Time",
    .basalEnergyBurned: "Basal Energy Burned",
    .cyclingCadence: "Cycling Cadence",
    .cyclingFunctionalThresholdPower: "Cycling Functional Threshold Power",
    .cyclingPower: "Cycling Power",
    .cyclingSpeed: "Cycling Speed",
    .distanceCycling: "Distance Cycling",
    .distanceDownhillSnowSports: "Distance Downhill Snow Sports",
    .distanceSwimming: "Distance Swimming",
    .distanceWalkingRunning: "Distance Walking/Running",
    .distanceWheelchair: "Distance Wheelchair",
    .flightsClimbed: "Flights Climbed",
    .nikeFuel: "Nike Fuel",
    .physicalEffort: "Physical Effort",
    .pushCount: "Push Count",
    .runningPower: "Running Power",
    .runningSpeed: "Running Speed",
    .stepCount: "Step Count",
    .swimmingStrokeCount: "Swimming Stroke Count",
    .underwaterDepth: "Underwater Depth",

    // Hearing Health
    .environmentalAudioExposure: "Environmental Audio Exposure",
    .environmentalSoundReduction: "Environmental Sound Reduction",
    .headphoneAudioExposure: "Headphone Audio Exposure",

    // Heart
    .atrialFibrillationBurden: "Atrial Fibrillation Burden",
    .heartRate: "Heart Rate",
    .heartRateRecoveryOneMinute: "Heart Rate Recovery (One Minute)",
    .heartRateVariabilitySDNN: "Heart Rate Variability (SDNN)",
    .peripheralPerfusionIndex: "Peripheral Perfusion Index",
    .restingHeartRate: "Resting Heart Rate",
    .vo2Max: "VO2 Max",
    .walkingHeartRateAverage: "Walking Heart Rate Average",

    // Mobility
    .appleWalkingSteadiness: "Walking Steadiness",
    .runningGroundContactTime: "Running Ground Contact Time",
    .runningStrideLength: "Running Stride Length",
    .runningVerticalOscillation: "Running Vertical Oscillation",
    .sixMinuteWalkTestDistance: "Six-Minute Walk Test Distance",
    .stairAscentSpeed: "Stair Ascent Speed",
    .stairDescentSpeed: "Stair Descent Speed",
    .walkingAsymmetryPercentage: "Walking Asymmetry Percentage",
    .walkingDoubleSupportPercentage: "Walking Double Support Percentage",
    .walkingSpeed: "Walking Speed",
    .walkingStepLength: "Walking Step Length",

    // Nutrition
    .dietaryBiotin: "Dietary Biotin",
    .dietaryCaffeine: "Dietary Caffeine",
    .dietaryCalcium: "Dietary Calcium",
    .dietaryCarbohydrates: "Dietary Carbohydrates",
    .dietaryChloride: "Dietary Chloride",
    .dietaryCholesterol: "Dietary Cholesterol",
    .dietaryChromium: "Dietary Chromium",
    .dietaryCopper: "Dietary Copper",
    .dietaryEnergyConsumed: "Dietary Energy Consumed",
    .dietaryFatMonounsaturated: "Dietary Fat (Monounsaturated)",
    .dietaryFatPolyunsaturated: "Dietary Fat (Polyunsaturated)",
    .dietaryFatSaturated: "Dietary Fat (Saturated)",
    .dietaryFatTotal: "Dietary Fat (Total)",
    .dietaryFiber: "Dietary Fiber",
    .dietaryFolate: "Dietary Folate",
    .dietaryIodine: "Dietary Iodine",
    .dietaryIron: "Dietary Iron",
    .dietaryMagnesium: "Dietary Magnesium",
    .dietaryManganese: "Dietary Manganese",
    .dietaryMolybdenum: "Dietary Molybdenum",
    .dietaryNiacin: "Dietary Niacin",
    .dietaryPantothenicAcid: "Dietary Pantothenic Acid",
    .dietaryPhosphorus: "Dietary Phosphorus",
    .dietaryPotassium: "Dietary Potassium",
    .dietaryProtein: "Dietary Protein",
    .dietaryRiboflavin: "Dietary Riboflavin",
    .dietarySelenium: "Dietary Selenium",
    .dietarySodium: "Dietary Sodium",
    .dietarySugar: "Dietary Sugar",
    .dietaryThiamin: "Dietary Thiamin",
    .dietaryVitaminA: "Dietary Vitamin A",
    .dietaryVitaminB12: "Dietary Vitamin B12",
    .dietaryVitaminB6: "Dietary Vitamin B6",
    .dietaryVitaminC: "Dietary Vitamin C",
    .dietaryVitaminD: "Dietary Vitamin D",
    .dietaryVitaminE: "Dietary Vitamin E",
    .dietaryVitaminK: "Dietary Vitamin K",
    .dietaryWater: "Dietary Water",
    .dietaryZinc: "Dietary Zinc",

    // Other
    .bloodAlcoholContent: "Blood Alcohol Content",
    .bloodPressureDiastolic: "Blood Pressure (Diastolic)",
    .bloodPressureSystolic: "Blood Pressure (Systolic)",
    .insulinDelivery: "Insulin Delivery",
    .numberOfAlcoholicBeverages: "Number of Alcoholic Beverages",
    .numberOfTimesFallen: "Number of Times Fallen",
    .timeInDaylight: "Time in Daylight",
    .uvExposure: "UV Exposure",
    .waterTemperature: "Water Temperature",

    // Reproductive Health
    .basalBodyTemperature: "Basal Body Temperature",

    // Respiratory
    .forcedExpiratoryVolume1: "Forced Expiratory Volume (1 second)",
    .forcedVitalCapacity: "Forced Vital Capacity",
    .inhalerUsage: "Inhaler Usage",
    .oxygenSaturation: "Oxygen Saturation",
    .peakExpiratoryFlowRate: "Peak Expiratory Flow Rate",
    .respiratoryRate: "Respiratory Rate",

    // Vital Signs
    .bloodGlucose: "Blood Glucose",
    .bodyTemperature: "Body Temperature",

    // Other recent identifiers
    .appleSleepingWristTemperature: "Sleeping Wrist Temperature",
  ]

  public let categoryMapping: [HKCategoryTypeIdentifier: String] = [
    // Stand Hour
    .appleStandHour: "Stand Hour",

    // Hearing Health
    .environmentalAudioExposureEvent: "Environmental Audio Exposure Event",
    .headphoneAudioExposureEvent: "Headphone Audio Exposure Event",

    // Heart
    .highHeartRateEvent: "High Heart Rate Event",
    .irregularHeartRhythmEvent: "Irregular Heart Rhythm Event",
    .lowCardioFitnessEvent: "Low Cardio Fitness Event",
    .lowHeartRateEvent: "Low Heart Rate Event",

    // Mindfulness
    .mindfulSession: "Mindful Session",

    // Mobility
    .appleWalkingSteadinessEvent: "Walking Steadiness Event",

    // Other
    .handwashingEvent: "Handwashing Event",
    .toothbrushingEvent: "Toothbrushing Event",

    // Reproductive Health
    .cervicalMucusQuality: "Cervical Mucus Quality",
    .contraceptive: "Contraceptive",
    .infrequentMenstrualCycles: "Infrequent Menstrual Cycles",
    .intermenstrualBleeding: "Intermenstrual Bleeding",
    .irregularMenstrualCycles: "Irregular Menstrual Cycles",
    .lactation: "Lactation",
    .menstrualFlow: "Menstrual Flow",
    .ovulationTestResult: "Ovulation Test Result",
    .persistentIntermenstrualBleeding: "Persistent Intermenstrual Bleeding",
    .pregnancy: "Pregnancy",
    .pregnancyTestResult: "Pregnancy Test Result",
    .progesteroneTestResult: "Progesterone Test Result",
    .prolongedMenstrualPeriods: "Prolonged Menstrual Periods",
    .sexualActivity: "Sexual Activity",

    // Sleep
    .sleepAnalysis: "Sleep Analysis",

    // Symptoms
    .abdominalCramps: "Abdominal Cramps",
    .acne: "Acne",
    .appetiteChanges: "Appetite Changes",
    .bladderIncontinence: "Bladder Incontinence",
    .bloating: "Bloating",
    .breastPain: "Breast Pain",
    .chestTightnessOrPain: "Chest Tightness or Pain",
    .chills: "Chills",
    .constipation: "Constipation",
    .coughing: "Coughing",
    .diarrhea: "Diarrhea",
    .dizziness: "Dizziness",
    .drySkin: "Dry Skin",
    .fainting: "Fainting",
    .fatigue: "Fatigue",
    .fever: "Fever",
    .generalizedBodyAche: "Generalized Body Ache",
    .hairLoss: "Hair Loss",
    .headache: "Headache",
    .heartburn: "Heartburn",
    .hotFlashes: "Hot Flashes",
    .lossOfSmell: "Loss of Smell",
    .lossOfTaste: "Loss of Taste",
    .lowerBackPain: "Lower Back Pain",
    .memoryLapse: "Memory Lapse",
    .moodChanges: "Mood Changes",
    .nausea: "Nausea",
    .nightSweats: "Night Sweats",
    .pelvicPain: "Pelvic Pain",
    .rapidPoundingOrFlutteringHeartbeat: "Rapid Pounding or Fluttering Heartbeat",
    .runnyNose: "Runny Nose",
    .shortnessOfBreath: "Shortness of Breath",
    .sinusCongestion: "Sinus Congestion",
    .skippedHeartbeat: "Skipped Heartbeat",
    .sleepChanges: "Sleep Changes",
    .soreThroat: "Sore Throat",
    .vaginalDryness: "Vaginal Dryness",
    .vomiting: "Vomiting",
    .wheezing: "Wheezing",
  ]

  public var quantityTypes: [HKQuantityType] = []
  public var categoryTypes: [HKCategoryType] = []

  // healthkit selected types
  @Published public var selectedQuantityTypes: Set<HKQuantityTypeIdentifier> = []

  // -MARK: User Interactions

  /// Selects the `HKQuantityTypeIdentifier`
  func toggleTypeIdentifier(_ identifier: HKQuantityTypeIdentifier) {
    if selectedQuantityTypes.contains(identifier) {
      selectedQuantityTypes.remove(identifier)
    } else {
      selectedQuantityTypes.insert(identifier)
    }
  }

  /// Clears the export queue
  func clearExportQueue() {
    selectedQuantityTypes.removeAll()
  }

  // -MARK: Intents

  /// Allows a date range to selected
  func dateSelectClicked() {
    logger.debug("Clicked the date select")
    dateSelectorEnabled.toggle()
  }

  /// Exports health data in an async function which can be exported to the transferable object w/ proper await support
  func asyncExportHealthData() async -> String {
    // analytics logging
    Task.detached {
      await MainActor.run { [weak self] in
        if let self = self { self.logExportOccurred() }
      }
    }

    return await withUnsafeContinuation { continuation in
      exportHealthData(continuation: continuation)
    }
  }

  /// Exports health data to the share sheet
  func exportHealthData(continuation: ExportContinuation) {
    // Converts the selected quantity types
    let generatedQuantityTypes: Set<HKObjectType> = Set(
      selectedQuantityTypes.map({
        HKObjectType.quantityType(forIdentifier: $0)!
      }))

    // TODO: Make this to where isAuthorizedForTypes filters the type so you do not get prompted for something that you already have authorization
    if !isAuthorizedForTypes(generatedQuantityTypes) {
      healthStore.requestAuthorization(toShare: nil, read: generatedQuantityTypes) {
        (success, error) in
        guard success else {
          logger.error("Failed w/ error \(error)")
          return
        }

        // queries data from HealthKit
        self.makeAuthorizedQueryToHealthKit(continuation)
      }
    } else {
      // queries data from HealthKit
      makeAuthorizedQueryToHealthKit(continuation)
    }
  }

  /// Check if we need authorization for a given set of object types
  func isAuthorizedForTypes(_ generatedQuantityTypes: Set<HKObjectType>) -> Bool {
    var isAuthorized = true
    for quantityType in generatedQuantityTypes {
      switch healthStore.authorizationStatus(for: quantityType) {
      case .notDetermined, .sharingDenied:
        isAuthorized = false
        break
      default:
        continue
      }
    }

    return isAuthorized
  }

  /// Makes a query to `HealthKit`
  func makeAuthorizedQueryToHealthKit(_ continuation: ExportContinuation) {
    // Ensure we have authorization to read health data
    guard HKHealthStore.isHealthDataAvailable() else {
      logger.error("Health data is not available")
      return
    }

    // we have authorization for exporting health data, we need ot do it
    let generatedQuantityTypes: Set<HKQuantityType> = Set(
      selectedQuantityTypes.map({
        HKQuantityType.quantityType(forIdentifier: $0)!
      }))

    // getting the prefered units
    healthStore.preferredUnits(for: generatedQuantityTypes) { (mapping, error) in
      if let error = error {
        logger.error("Failed to generate the preferred unit types \(error)")

        // calling without a units mapping
        self.fetchDataForCompletion(
          continuation: continuation, generatedQuantityTypes: generatedQuantityTypes,
          unitsMapping: [:])
      } else {
        self.fetchDataForCompletion(
          continuation: continuation, generatedQuantityTypes: generatedQuantityTypes,
          unitsMapping: mapping)
      }
    }
  }

  /// Gets the data for each type
  func fetchDataForCompletion(
    continuation: ExportContinuation, generatedQuantityTypes: Set<HKQuantityType>,
    unitsMapping: [HKObjectType: HKUnit]
  ) {
    let dispatchGroup = DispatchGroup()

    var resultsDictionary: [HKObjectType: [HKSample]] = [:]

    for quantityType in quantityTypes {
      // fetching in a dispatch group
      dispatchGroup.enter()

      // calling the function
      let query = HKSampleQuery(
        sampleType: quantityType, predicate: nil, limit: 1000, sortDescriptors: nil
      ) { query, sample, error in
        if let error = error {
          logger.error("Failed to fetch data with error \(error)")
          dispatchGroup.leave()
          return
        }

        if let sample = sample {
          resultsDictionary[quantityType] = sample
        }

        dispatchGroup.leave()
      }

      healthStore.execute(query)
    }

    dispatchGroup.notify(queue: .main) {
      // we then need to convert it
      self.makeCSVFromDictionaryToKeys(
        resultsDictionary, continuation: continuation, unitsMapping: unitsMapping)
    }
  }

  /// Turns the results into a CSV list
  func makeCSVFromDictionaryToKeys(
    _ resultsDict: [HKObjectType: [HKSample]], continuation: ExportContinuation,
    unitsMapping: [HKObjectType: HKUnit]
  ) {
    // getting the unit type mapping
    var returnString = "Date,Time,Unit,Value"

    for quantityType in resultsDict.keys {
      let preferredUnit = unitsMapping[quantityType]

      for entry in resultsDict[quantityType] ?? [] {
        let newEntry = entry as! HKQuantitySample
        if let unit = preferredUnit {
          let value = newEntry.quantity.doubleValue(for: unit)
          let startDate = itemFormatter.string(from: entry.startDate)

          returnString += "\n\(startDate),\(unit.unitString),\(value)"
        } else {
          let fallbackUnits: [HKUnit] = [
            .gram(), .ounce(), .pound(), .stone(),
            .meter(), .inch(), .foot(), .mile(),
            .liter(), .fluidOunceUS(), .fluidOunceImperial(), .pintUS(), .pintImperial(),
            .second(), .minute(), .hour(), .day(),
            .joule(), .kilocalorie(),
            .degreeCelsius(), .degreeFahrenheit(), .kelvin(),
            .siemen(),
            .hertz(),
            .volt(),
            .watt(),
            .radianAngle(), .degreeAngle(),
            .lux(),
          ]

          if let fallbackUnit = fallbackUnits.first(where: {
            newEntry.quantityType.is(compatibleWith: $0)
          }) {
            let value = newEntry.quantity.doubleValue(for: fallbackUnit)
            let startDate = itemFormatter.string(from: entry.startDate)

            returnString += "\n\(startDate),\(fallbackUnit.unitString),\(value)"
          } else {
            logger.debug(
              "No compatible unit found, skipping entry for quantity type: \(quantityType.identifier)"
            )
          }
        }
      }
    }

    // we need to return this string somehow to the user to make data out of it!
    continuation.resume(returning: returnString)
  }

  /// Makes a list of types selected to show for the user's summary
  public func makeSelectedStringDescription() -> String {
    return selectedQuantityTypes.map({ quantityMapping[$0]! }).sorted().joined(separator: ", ")
  }

  /// Analytics reporting which may ask for a review if numbers are high enough
  @MainActor func logExportOccurred() {
    timesExported += 1
    categoriesExported += selectedQuantityTypes.count

    // decision point on whether or not to ask for a review
    if timesExported >= 2 || categoriesExported >= 10, let bundle = Bundle.main.bundleIdentifier,
      lastRequested != bundle
    {
      lastRequested = bundle

      DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
        if let self = self {
          self.requestReview()
        }
      }
    }
  }

  /// Exporting condensed workout samples
  /// source: https://developer.apple.com/documentation/healthkit/workouts_and_activity_rings/accessing_condensed_workout_samples
  func exportCondensedWorkoutSamples() {
    // this is a workout type which is pretty interesting tbh
    let forWorkout = HKQuery.predicateForWorkoutActivities(workoutActivityType: .archery)
    let heartRateType: HKSampleType = .workoutType()
    //        let test = HKQuery.predicateForObjects(from: HKSource)
    //        let heartRateDescriptor = HKQueryDescriptor(sampleType: forWorkout, predicate: forWorkout)
    let heartRateDescriptor = HKQueryDescriptor(sampleType: heartRateType, predicate: forWorkout)

    let heartRateQuery = HKSampleQuery(
      queryDescriptors: [heartRateDescriptor], limit: HKObjectQueryNoLimit
    ) { query, samples, error in

    }
  }
}

/// A `CategoryGroup` links together quantity and category types into an object used to represent a user interface menu
struct CategoryGroup: Hashable {
  let name: String
  let quantities: [HKQuantityTypeIdentifier]
  let categories: [HKCategoryTypeIdentifier]

  var hasBoth: Bool {
    quantities.count != 0 && categories.count != 0
  }
}

let bodyMeasurementsGroup = CategoryGroup(
  name: "Body Measurements",
  quantities: [
    .bodyMass, .bodyMassIndex, .leanBodyMass, .height, .waistCircumference, .bodyFatPercentage,
    .electrodermalActivity,
  ],
  categories: []
)

let fitnessGroup = CategoryGroup(
  name: "Fitness",
  quantities: [
    .activeEnergyBurned, .appleExerciseTime, .appleMoveTime, .appleStandTime, .basalEnergyBurned,
    .cyclingCadence,
    .cyclingFunctionalThresholdPower, .cyclingPower, .cyclingSpeed, .distanceCycling,
    .distanceDownhillSnowSports,
    .distanceSwimming, .distanceWalkingRunning, .distanceWheelchair, .flightsClimbed,
    .physicalEffort, .pushCount,
    .runningPower, .runningSpeed, .stepCount, .swimmingStrokeCount, .underwaterDepth,
  ],
  categories: []
)

let hearingHealthGroup = CategoryGroup(
  name: "Hearing Health",
  quantities: [
    .environmentalAudioExposure, .environmentalSoundReduction, .headphoneAudioExposure,
  ],
  categories: [
    .environmentalAudioExposureEvent, .headphoneAudioExposureEvent,
  ]
)

let heartGroup = CategoryGroup(
  name: "Heart",
  quantities: [
    .atrialFibrillationBurden, .heartRate, .heartRateRecoveryOneMinute, .heartRateVariabilitySDNN,
    .peripheralPerfusionIndex,
    .restingHeartRate, .vo2Max, .walkingHeartRateAverage,
  ],
  categories: [
    .highHeartRateEvent, .irregularHeartRhythmEvent, .lowCardioFitnessEvent, .lowHeartRateEvent,
  ]
)

let mobilityGroup = CategoryGroup(
  name: "Mobility",
  quantities: [
    .appleWalkingSteadiness, .runningGroundContactTime, .runningStrideLength,
    .runningVerticalOscillation,
    .sixMinuteWalkTestDistance, .stairAscentSpeed, .stairDescentSpeed, .walkingAsymmetryPercentage,
    .walkingDoubleSupportPercentage, .walkingSpeed, .walkingStepLength,
  ],
  categories: [
    .appleWalkingSteadinessEvent
  ]
)

let nutritionGroup = CategoryGroup(
  name: "Nutrition",
  quantities: [
    .dietaryBiotin, .dietaryCaffeine, .dietaryCalcium, .dietaryCarbohydrates, .dietaryChloride,
    .dietaryCholesterol,
    .dietaryChromium, .dietaryCopper, .dietaryEnergyConsumed, .dietaryFatMonounsaturated,
    .dietaryFatPolyunsaturated,
    .dietaryFatSaturated, .dietaryFatTotal, .dietaryFiber, .dietaryFolate, .dietaryIodine,
    .dietaryIron, .dietaryMagnesium,
    .dietaryManganese, .dietaryMolybdenum, .dietaryNiacin, .dietaryPantothenicAcid,
    .dietaryPhosphorus, .dietaryPotassium,
    .dietaryProtein, .dietaryRiboflavin, .dietarySelenium, .dietarySodium, .dietarySugar,
    .dietaryThiamin, .dietaryVitaminA,
    .dietaryVitaminB12, .dietaryVitaminB6, .dietaryVitaminC, .dietaryVitaminD, .dietaryVitaminE,
    .dietaryVitaminK, .dietaryWater,
    .dietaryZinc,
  ],
  categories: []
)

let otherGroup = CategoryGroup(
  name: "Other",
  quantities: [
    .bloodAlcoholContent, .bloodPressureDiastolic, .bloodPressureSystolic, .insulinDelivery,
    .numberOfAlcoholicBeverages,
    .numberOfTimesFallen, .timeInDaylight, .uvExposure, .waterTemperature,
    .appleSleepingWristTemperature, .basalBodyTemperature,
  ],
  categories: [
    .handwashingEvent, .toothbrushingEvent,
  ]
)

let reproductiveHealthGroup = CategoryGroup(
  name: "Reproductive Health",
  quantities: [
    //        .basalBodyTemperature
  ],
  categories: [
    .cervicalMucusQuality, .contraceptive, .infrequentMenstrualCycles, .intermenstrualBleeding,
    .irregularMenstrualCycles,
    .lactation, .menstrualFlow, .ovulationTestResult, .persistentIntermenstrualBleeding, .pregnancy,
    .pregnancyTestResult,
    .progesteroneTestResult, .prolongedMenstrualPeriods, .sexualActivity,
  ]
)

let respiratoryGroup = CategoryGroup(
  name: "Respiratory",
  quantities: [
    .forcedExpiratoryVolume1, .forcedVitalCapacity, .inhalerUsage, .oxygenSaturation,
    .peakExpiratoryFlowRate, .respiratoryRate,
  ],
  categories: []
)

let sleepGroup = CategoryGroup(
  name: "Sleep",
  quantities: [],
  categories: [
    .sleepAnalysis
  ]
)

let symptomsGroup = CategoryGroup(
  name: "Symptoms",
  quantities: [],
  categories: [
    .abdominalCramps, .acne, .appetiteChanges, .bladderIncontinence, .bloating, .breastPain,
    .chestTightnessOrPain,
    .chills, .constipation, .coughing, .diarrhea, .dizziness, .drySkin, .fainting, .fatigue, .fever,
    .generalizedBodyAche,
    .hairLoss, .headache, .heartburn, .hotFlashes, .lossOfSmell, .lossOfTaste, .lowerBackPain,
    .memoryLapse, .moodChanges,
    .nausea, .nightSweats, .pelvicPain, .rapidPoundingOrFlutteringHeartbeat, .runnyNose,
    .shortnessOfBreath,
    .sinusCongestion, .skippedHeartbeat, .sleepChanges, .soreThroat, .vaginalDryness, .vomiting,
    .wheezing,
  ]
)

let vitalSignsGroup = CategoryGroup(
  name: "Vital Signs",
  quantities: [
    .bloodGlucose, .bodyTemperature,
  ],
  categories: []
)
