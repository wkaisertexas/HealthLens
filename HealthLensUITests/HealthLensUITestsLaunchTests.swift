import XCTest

final class HealthLensUITestsLaunchTests: XCTestCase {
  override class var runsForEachTargetApplicationUIConfiguration: Bool {
    return false
  }

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  let locales = ["ar", "fr_FR", "es_ES"]

  func testLaunch() throws {
    for locale in locales {
      let app = XCUIApplication()

      // 1) Set up the environment and arguments for the locale
      // AppleLanguages is an array; AppleLocale is a single string
      app.launchArguments += [
        "-AppleLanguages", "(\(locale))",
        "-AppleLocale", locale,
      ]
      // Optional: Set measurement units, temperature units, etc. if needed
      // app.launchArguments += ["-AppleMeasurementUnits", "Centimeters", "-AppleTemperatureUnit", "Celsius"]

      // Launch the app
      app.launch()

      // Screenshot + add it to the test result
      let screenshot = app.screenshot()
      let attachment = XCTAttachment(screenshot: screenshot)

      attachment.name = "\(locale)-HomeScreen"
      attachment.lifetime = .keepAlways

      add(attachment)
    }
  }
}
