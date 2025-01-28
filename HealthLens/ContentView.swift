import HealthKit
import SwiftData
import SwiftUI

/// Represents the main content which is present in the application
struct ContentView: View {
  @ObservedObject private var contentViewModel = ContentViewModel()

  @Environment(\.requestReview) private var requestReview

  var body: some View {
    NavigationStack {
      List {
        Section {
          VStack {
            Text("HealthLens").font(.largeTitle).fontWeight(.bold).frame(
              maxWidth: .infinity, alignment: .leading)
            Text("Export your health data as a CSV").font(.subheadline).frame(
              maxWidth: .infinity, alignment: .leading)
          }

          Link(
            destination: URL(
              string: "https://raw.githubusercontent.com/wkaisertexas/HealthLens/main/PRIVACY.md")!
          ) {
            HStack {
              Image(systemName: "lock.shield.fill")
                .foregroundColor(.blue)
              Text("Privacy Policy")
            }
          }

          Link(destination: URL(string: "https://github.com/wkaisertexas/healthlens")!) {
            HStack {
              Image(systemName: "chevron.left.slash.chevron.right")
                .foregroundColor(.green)
              Text("Contribute on GitHub")
            }
          }

          Button(action: { requestReview() }) {
            HStack {
              Image(systemName: "star.fill")
                .foregroundColor(.yellow)
              Text("Leave a Review")
            }
          }
        }

        Section {
          Button(action: {
            contentViewModel.exportAllHealthData()
          }) {
            HStack {
              Image(systemName: "square.and.arrow.up.on.square").foregroundColor(.blue)
              Text("Export All Health Data")
            }
          }

          Picker("Export Format", selection: $contentViewModel.selectedExportFormat) {
            ForEach(ExportFormat.allCases, id: \.self) { format in
              Text(format.rawValue.uppercased())
            }
          }.onChange(of: contentViewModel.selectedExportFormat) { _, newValue in
            contentViewModel.onSelectedExportFormatChange(newValue)
          }
        } header: {
          Text("Export All")
        }

        // Date range selector
        Section {
          VStack {
            Text("Select a date range to export health data").fontWeight(.bold).frame(
              maxWidth: .infinity, alignment: .leading)
            DatePicker(
              "Start Date", selection: $contentViewModel.startDate, in: ...contentViewModel.endDate,
              displayedComponents: [.date])
            DatePicker(
              "End Date", selection: $contentViewModel.endDate,
              in: contentViewModel.startDate...contentViewModel.currentDate,
              displayedComponents: [.date])
          }
        } header: {
          Text("Export Range")
        }

        // Going through each category type
        ForEach(contentViewModel.categoryGroups, id: \.self) { category in
          Section(category.name) {
            ForEach(
              category.quantities.sorted(by: {
                contentViewModel.quantityMapping[$1]! > contentViewModel.quantityMapping[$0]!
              }), id: \.self
            ) { quant in
              Button(action: {
                withAnimation {
                  contentViewModel.toggleTypeIdentifier(quant)
                }
              }) {
                HStack {
                  Text(contentViewModel.quantityMapping[quant]!).foregroundStyle(Color.primary)
                  Spacer()
                  contentViewModel.selectedQuantityTypes.contains(quant)
                    ? Image(systemName: "checkmark").foregroundColor(.blue) : nil
                }
              }
            }
          }
        }
      }
      .navigationTitle(
        Text(
          contentViewModel.selectedQuantityTypes.count > 0
            ? "Exporting \(contentViewModel.selectedQuantityTypes.count) item\(contentViewModel.selectedQuantityTypes.count == 1 ? "": "s")"
            : "")
      )
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .automatic) {
          //- NOTE: This is causing type-checking to fail here for some reason
          
          ShareLink(
            item: contentViewModel.exportFile,
            preview: SharePreview(
              "Exporting \(contentViewModel.makeSelectedStringDescription())")
          ).disabled(contentViewModel.selectedQuantityTypes.count == 0)
        }

        ToolbarItem(placement: .topBarLeading) {
          Button(action: {
            withAnimation {
              contentViewModel.clearExportQueue()
            }
          }) {
            Image(systemName: "clear")
          }
          .accessibilityHint("Clear the selected HealthKit types")
          .disabled(contentViewModel.selectedQuantityTypes.count == 0)
        }
      }
    }
  }
}

let itemFormatter: DateFormatter = {
  let formatter = DateFormatter()

  formatter.dateStyle = .short
  formatter.timeStyle = .short
  formatter.locale = Locale.current

  return formatter
}()

#Preview {
  ContentView()
}
