import HealthKit

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
