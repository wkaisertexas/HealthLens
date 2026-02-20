import SwiftData
import SwiftUI

@main
struct HealthLensApp: App {
  @StateObject private var contentViewModel = ContentViewModel()

  var body: some Scene {
    WindowGroup {
      ContentView(contentViewModel: contentViewModel)
    }
  }
}
