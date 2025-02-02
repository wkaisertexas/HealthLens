import HealthKit
import StoreKit
import SwiftUI
import libxlsxwriter

let export_count = 2  //< How many unique exports must be asked for before a review
let categories_exported = 10  //< Categories exported before a review is asked for
let time_difference_large_enough: TimeInterval = 1 * 24 * 60 * 60  //< 1 Day in seconds
let sample_cap = 50_000  //< Max number of samples to export

/// Contains all of the data to store the necessary health records
class ContentViewModel: ObservableObject {
  private let healthStore = HKHealthStore()
  typealias ExportContinuation = UnsafeContinuation<URL, Never>

  @Published public var searchText: String = ""

  @AppStorage("exportFormat") public var selectedExportFormat: ExportFormat = .csv

  let header_datetime = String(localized: "Datetime")
  let header_category = String(localized: "Category")
  let header_unit = String(localized: "Unit")
  let header_value = String(localized: "Value")

  var xlsx_headers: [String] {
    return [
      header_datetime,
      header_category,
      header_unit,
      header_value,
    ]
  }
  var csv_headers: [String] {
    return [
      header_datetime,
      header_category,
      header_unit,
      header_value,
    ]
  }

  private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()

    formatter.dateStyle = .short
    formatter.timeStyle = .short
    formatter.locale = Locale.current

    return formatter
  }()

  private let numberFormatter: NumberFormatter = {
    let formatter = NumberFormatter()

    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = 2
    formatter.locale = Locale.current

    return formatter
  }()

  // -MARK: Stateful representations of the input form
  public var xlsxShareTarget: XLSXExportFile
  public var csvShareTarget: CSVExportFile

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
    if selectedQuantityTypes.count == total_exports {
      return "all-health-data"
    }

    let result =
      selectedQuantityTypes
      .map { quantityMapping[$0]! }
      .sorted()
      .joined(separator: "-")
      .replacingOccurrences(of: " ", with: ".").lowercased()

    return "\(result)"
  }

  public init() {
    // Setting up the two export files
    xlsxShareTarget = XLSXExportFile()
    csvShareTarget = CSVExportFile()

    xlsxShareTarget.collectData = asyncExportHealthData
    csvShareTarget.collectData = asyncExportHealthData
    xlsxShareTarget.fileName = suggestedFileName
    csvShareTarget.fileName = suggestedFileName

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
    respiratoryGroup,
    vitalSignsGroup,
    otherGroup,
    respiratoryGroup,

    // reproductiveHealthGroup,
    // sleepGroup,
    // symptomsGroup,

    // TODO: Add a way to export this commented out categories
    // reproductiveHealthGroup,
    // sleepGroup,
    // symptomsGroup,
    // nutritionGroup,
  ]
  var filteredCategoryGroups: [CategoryGroup] {
    // return everything if empty
    guard !searchText.isEmpty else {
      return categoryGroups
    }

    let lowercasedSearch = searchText.lowercased()

    // Filter
    let filteredGroups = categoryGroups.map { group in
      let filteredQuantities = group.quantities.filter { quantityIdentifier in
        if let name = quantityMapping[quantityIdentifier] {
          return name.lowercased().contains(lowercasedSearch)
        }
        return false
      }

      return CategoryGroup(name: group.name, quantities: filteredQuantities, categories: [])
    }
    .filter { !$0.quantities.isEmpty }  // need at least one match

    return filteredGroups
  }

  var total_exports: Int {
    categoryGroups.map { $0.quantities.count + $0.categories.count }.reduce(0, +)
  }

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

  public var quantityTypes: [HKQuantityType] = []
  public var categoryTypes: [HKCategoryType] = []

  // healthkit selected types
  @AppStorage("selectedQuantityTypes") public var selectedQuantityTypes:
    Set<HKQuantityTypeIdentifier> = []

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
  func asyncExportHealthData() async -> URL {
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
      }

      self.fetchDataForCompletion(
        continuation: continuation, generatedQuantityTypes: generatedQuantityTypes,
        unitsMapping: mapping)
    }
  }

  /// Gets the data for each type
  func fetchDataForCompletion(
    continuation: ExportContinuation, generatedQuantityTypes: Set<HKQuantityType>,
    unitsMapping: [HKObjectType: HKUnit]
  ) {
    let dispatchGroup = DispatchGroup()

    var resultsDictionary: [HKObjectType: [HKSample]] = [:]

    for quantityType in generatedQuantityTypes {
      // fetching in a dispatch group
      dispatchGroup.enter()

      // calling the function
      let query = HKSampleQuery(
        sampleType: quantityType, predicate: make_date_range_predicate(), limit: sample_cap,
        sortDescriptors: nil
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
      switch self.selectedExportFormat {
      case .csv:
        self.exportCSVData(
          resultsDictionary, continuation: continuation, unitsMapping: unitsMapping)
      case .xlsx:
        self.exportELSXData(
          resultsDictionary, continuation: continuation, unitsMapping: unitsMapping)
      }
    }
  }

  /// Cleans up a csv string for santization
  func sanitizeForCSV(_ input: String) -> String {
    var sanitized = input

    // Escape double quotes by replacing `"` with `""`
    sanitized = sanitized.replacingOccurrences(of: "\"", with: "\"\"")

    // If the string contains a comma, newline, or double quote, wrap it in quotes
    if sanitized.contains(",") || sanitized.contains("\n") || sanitized.contains("\"") {
      sanitized = "\"\(sanitized)\""
    }

    return sanitized
  }

  /// Turns the results into a CSV list
  func exportCSVData(
    _ resultsDict: [HKObjectType: [HKSample]], continuation: ExportContinuation,
    unitsMapping: [HKObjectType: HKUnit]
  ) {
    let uuid = UUID().uuidString
    let fileName = "HealthData\(uuid).csv"
    let fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)

    var returnString = "\(header_datetime),\(header_category),\(header_unit),\(header_value)\n"

    for quantityType in resultsDict.keys {
      let quantity_type_id = HKQuantityTypeIdentifier(rawValue: quantityType.identifier)
      let quantity_type_string = sanitizeForCSV(
        quantityMapping[quantity_type_id] ?? String(localized: "Unknown"))

      for entry in resultsDict[quantityType] ?? [] {
        let newEntry = entry as! HKQuantitySample

        var startDate = itemFormatter.string(from: entry.startDate)
        startDate = sanitizeForCSV(startDate)

        guard
          let unit = unitsMapping[quantityType]
            ?? fallbackUnits.first(where: {
              newEntry.quantityType.is(compatibleWith: $0)
            })
        else {
          logger.debug(
            "No compatible unit found, skipping entry for quantity type: \(quantityType.identifier)"
          )
          continue
        }

        let value_raw = newEntry.quantity.doubleValue(for: unit)
        var value = numberFormatter.string(from: value_raw as NSNumber) ?? String(value_raw)

        value = sanitizeForCSV(value)

        returnString += "\(startDate),\(quantity_type_string),\(unit.unitString),\(value)\n"
      }
    }

    do {
      try returnString.write(to: fileURL, atomically: true, encoding: .utf8)
      // Resume continuation with the file URL
      continuation.resume(returning: fileURL)
    } catch {
      logger.error("Failed to write CSV data to file: \(error)")
      // Resume continuation with a failure
      //        continuation.resume(throwing: error)
    }
  }

  func exportELSXData(
    _ resultsDict: [HKObjectType: [HKSample]], continuation: ExportContinuation,
    unitsMapping: [HKObjectType: HKUnit]
  ) {
    let uuid = UUID().uuidString
    let fileName = "HealthData\(uuid).xlsx"

    // Make a fileName be random here a uuid
    let filePath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
      .path

    guard let workbook = workbook_new(filePath) else {
      logger.error("Failed to create XLSX workbook at path: \(filePath)")
      //        continuation.resume(returning: Data())
      return
    }

    guard let worksheet = workbook_add_worksheet(workbook, String(localized: "Data")) else {
      logger.error("Failed to create XLSX worksheet.")
      workbook_close(workbook)
      //        continuation.resume(returning: Data())
      return
    }

    // MARK: Formats
    let header_format = workbook_add_format(workbook)
    format_set_bold(header_format)

    let datetime_format = workbook_add_format(workbook)
    if let date_format_string = itemFormatter.dateFormat {
      format_set_num_format(datetime_format, date_format_string)
    } else {
      logger.error("Failed to get date format string from localized date")
      format_set_num_format(datetime_format, "yyyy-MM-dd HH:mm:ss")
    }

    let number_format = workbook_add_format(workbook)
    if let number_format_string = numberFormatter.positiveFormat {
      format_set_num_format(number_format, number_format_string)
    } else {
      format_set_num_format(number_format, "#,##0.00")
    }

    // Growing column width
    worksheet_set_column_pixels(worksheet, 0, 0, 120, nil)
    worksheet_set_column_pixels(worksheet, 1, 1, 80, nil)
    worksheet_set_column_pixels(worksheet, 2, 2, 40, nil)
    worksheet_set_column_pixels(worksheet, 3, 3, 80, nil)

    for (colIndex, header) in xlsx_headers.enumerated() {
      worksheet_write_string(worksheet, 0, lxw_col_t(colIndex), header, header_format)
    }

    var currentRow: lxw_row_t = 1

    for (quantityType, samples) in resultsDict {
      let preferredUnit = unitsMapping[quantityType]
      let quantity_type_id = HKQuantityTypeIdentifier(rawValue: quantityType.identifier)
      let quantity_type_string = quantityMapping[quantity_type_id] ?? String(localized: "Unknown")

      for sample in samples {
        guard let quantitySample = sample as? HKQuantitySample else { continue }

        // Get the right unit to use per type
        let unitToUse: HKUnit? =
          preferredUnit
          ?? fallbackUnits.first {
            quantitySample.quantityType.is(compatibleWith: $0)
          }

        guard let finalUnit = unitToUse else {
          logger.debug(
            "No compatible unit found, skipping entry for type: \(quantityType.identifier)")
          continue
        }

        // Get the unit's numeric value
        let value = quantitySample.quantity.doubleValue(for: finalUnit)

        worksheet_write_unixtime(
          worksheet, currentRow, 0, Int64(quantitySample.startDate.timeIntervalSince1970),
          datetime_format)
        worksheet_write_string(worksheet, currentRow, 1, quantity_type_string, nil)
        worksheet_write_string(worksheet, currentRow, 2, finalUnit.unitString, nil)
        worksheet_write_number(worksheet, currentRow, 3, value, number_format)

        currentRow += 1
      }
    }

    // Finalizes the file by closing the workbook
    workbook_close(workbook)

    let fileURL = URL(fileURLWithPath: filePath)

    continuation.resume(returning: fileURL)
  }

  /// Makes a comma separated list of selectedQuantityTypes
  public func makeSelectedStringDescription() -> String {
    return selectedQuantityTypes.map({ quantityMapping[$0]! }).sorted().joined(separator: ", ")
  }

  /// Makes a predicate only if the range is large enough
  public func make_date_range_predicate() -> NSPredicate? {
    if abs(endDate.timeIntervalSince(startDate)) <= time_difference_large_enough {
      return nil
    }

    return HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
  }

  /// Analytics reporting which may ask for a review if numbers are high enough
  @MainActor func logExportOccurred() {
    timesExported += 1
    categoriesExported += selectedQuantityTypes.count

    // decision point on whether or not to ask for a review
    if timesExported >= export_count || categoriesExported >= categories_exported,
      let bundle = Bundle.main.bundleIdentifier,
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

  let quantityMapping: [HKQuantityTypeIdentifier: String] = [
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

  let categoryMapping: [HKCategoryTypeIdentifier: String] = [
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
}

// MARK: Codable - RawRepresentable Set extensions to use @AppStorage with selectedQuantityTypes
extension HKQuantityTypeIdentifier: Codable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    // Attempt to rebuild the identifier from its string rawValue
    self = HKQuantityTypeIdentifier(rawValue: rawValue)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(self.rawValue)
  }
}

extension Set: @retroactive RawRepresentable where Element: Codable {
  public init?(rawValue: String) {
    guard let data = rawValue.data(using: .utf8),
      let result = try? JSONDecoder().decode(Set<Element>.self, from: data)
    else {
      return nil
    }
    self = result
  }

  public var rawValue: String {
    guard let data = try? JSONEncoder().encode(self),
      let result = String(data: data, encoding: .utf8)
    else {
      // Fallback for encoding failure.
      return "[]"
    }
    return result
  }
}
