import HealthKit
import SwiftData
import SwiftUI

/// Represents the main content which is present in the application
struct ContentView: View {
  @ObservedObject private var contentViewModel = ContentViewModel()

  @Environment(\.requestReview) private var requestReview

  var body: some View {
    NavigationSplitView {
      if let selectedTypesDescription = contentViewModel.makeSelectedStringDescription() {
        HStack {
          ScrollView(.horizontal) {
            (Text("Exporting (\(contentViewModel.selectedQuantityTypes.count)) ").fontWeight(
              .semibold) + Text(selectedTypesDescription)).padding().lineLimit(1)
          }
          Spacer()
          Button(action: {
            withAnimation {
              contentViewModel.clearExportQueue()
            }
          }) {
            Image(systemName: "clear")
          }
        }.padding()
      }

      List {
        Section("Info") {
          VStack {
            Text("HealthLens").font(.largeTitle).fontWeight(.bold).frame(
              maxWidth: .infinity, alignment: .leading)
            Text("Export your Health Data to a CSV").font(.subheadline).frame(
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
                  Text(contentViewModel.quantityMapping[quant]!)
                  Spacer()
                  contentViewModel.selectedQuantityTypes.contains(quant)
                    ? Image(systemName: "checkmark").foregroundColor(.blue) : nil
                }
              }
            }

            //                        category.hasBoth ? Spacer() : nil
            //
            //                        ForEach(category.categories, id: \.self){ cat in
            //                            Button(action: {
            //                                withAnimation{
            //                                    contentViewModel.toggleTypeIdentifier(cat)
            //                                }
            //                            }){
            //                                HStack{
            //                                    Text(contentViewModel.categoryMapping[cat]!)
            //                                    Spacer()
            //                                    contentViewModel.selectedQuantityTypes.contains(quant) ? Image(systemName: "checkmark").foregroundColor(.blue) : nil
            //                                }
            //                            }
            //                        }
          }
        }
      }
      .toolbar {
        ToolbarItem(placement: .automatic) {
          ShareLink(
            item: contentViewModel.shareTarget,
            preview: SharePreview(
              contentViewModel.makeSelectedStringDescription() ?? "Exporting health data")
          ).disabled(contentViewModel.selectedQuantityTypes.count == 0)
        }
      }
    } detail: {
      Text("Select heath categories to export")
    }
  }
}

let itemFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateStyle = .short
  formatter.timeStyle = .short
  return formatter
}()

#Preview {
  ContentView()
    .modelContainer(for: Item.self, inMemory: true)
}
