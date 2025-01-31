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
        if contentViewModel.searchText.isEmpty {
          above_the_fold()
            .transition(.move(edge: .top).combined(with: .opacity))
        }
        make_groups_section()
      }
      .animation(.easeInOut, value: contentViewModel.searchText)
      .navigationTitle(
        Text(
          contentViewModel.selectedQuantityTypes.count > 0
            ? "Exporting \(contentViewModel.selectedQuantityTypes.count) item\(contentViewModel.selectedQuantityTypes.count == 1 ? "": "s")"
            : "")
      )
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .automatic) {
          make_share_link()
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
      }.searchable(
        text: $contentViewModel.searchText,
        prompt: "Search Health Data"
      )
    }
  }

  @ViewBuilder
  func above_the_fold() -> some View {
    createHeader()
    make_export_format()
    make_data_range_selector()
  }

  func createHeader() -> some View {
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
  }

  @ViewBuilder
  func make_share_link() -> some View {
    let excelPreviewIcon = Image("Excel")
    let csvPreviewIcon = Image("CSV")

    switch contentViewModel.selectedExportFormat {
    case .csv:
      ShareLink(
        item: contentViewModel.csvShareTarget,
        preview: SharePreview(
          "Exporting \(contentViewModel.makeSelectedStringDescription())",
          icon: csvPreviewIcon)
      ).disabled(contentViewModel.selectedQuantityTypes.count == 0)
    case .xlsx:
      ShareLink(
        item: contentViewModel.xlsxShareTarget,
        preview: SharePreview(
          "Exporting \(contentViewModel.makeSelectedStringDescription())",
          icon: excelPreviewIcon
        )
      ).disabled(contentViewModel.selectedQuantityTypes.count == 0)
    }
  }

  func make_export_format() -> some View {
    Section {
      Picker("Export Format", selection: $contentViewModel.selectedExportFormat) {
        ForEach(ExportFormat.allCases, id: \.self) { format in
          Text(format.rawValue.uppercased())
        }
      }
    } header: {
      Text("Export Format")
    }
  }

  func make_data_range_selector() -> some View {
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
  }

  @ViewBuilder
  func make_groups_section() -> some View {
    let groups = contentViewModel.filteredCategoryGroups

    groups.count == 0
      ? Section {
        Text("No results for \"\(contentViewModel.searchText)\"")
          .font(.callout)
          .foregroundColor(.secondary)
          .padding(.vertical, 8)
      } : nil

    ForEach(contentViewModel.filteredCategoryGroups, id: \.self) { category in
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

}

#Preview {
  ContentView()
}
