# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
open HealthLens.xcodeproj                        # Open in Xcode, Cmd+R to run
xcodebuild test -scheme HealthLens               # Run all tests
xcodebuild test -scheme HealthLens \
  -only-testing:HealthLensTests/HealthLensTests/testCSVSanitization  # Run single test
```

No SPM command-line build — uses Xcode project with HealthKit framework and libxlsxwriter SPM dependency. Tests require the simulator (HealthKit types can't instantiate without it).

## Architecture

Single-screen MVVM app — one view, one view model, no navigation:

- **`HealthLensApp.swift`** — Creates `ContentViewModel` as `@StateObject`, passes to `ContentView`
- **`ContentViewModel.swift`** (~950 lines) — All business logic lives here: HealthKit authorization, sample querying, CSV/XLSX export, sample aggregation, and the `quantityMapping`/`categoryMapping` dictionaries that define all supported health types
- **`ContentView.swift`** — SwiftUI list with search, date range pickers, category sections, and `ShareLink` for export
- **`ExportFile.swift`** — `CSVExportFile` and `XLSXExportFile` structs conforming to `Transferable`; use closure-based `collectData` pattern to defer async export until share sheet needs it
- **`Groups.swift`** — `CategoryGroup` structs that organize `HKQuantityTypeIdentifier`s into UI sections. Some groups are commented out (nutrition, sleep, symptoms, reproductive health)

### Export Flow

1. User selects health types via `toggleTypeIdentifier()` → stored in `@AppStorage("selectedQuantityTypes")`
2. User taps ShareLink → triggers `asyncExportHealthData()` via `Transferable` conformance
3. HealthKit authorization requested if needed → `preferredUnits` fetched → `fetchDataForCompletion` queries each type in a `DispatchGroup`
4. Consecutive samples merged via `mergeConsecutiveSamples()` (~3x compression)
5. Results written to temp file as CSV (string building) or XLSX (libxlsxwriter C API)

### Testability

`HealthStoreProtocol` (defined at bottom of `ContentViewModel.swift`) abstracts HealthKit. Three mock implementations exist in test files:
- `MockHealthStore` — empty results, tracks authorization calls
- `MockHealthStoreWithData` — configurable sample counts with realistic values
- `MockHealthStoreWithConsecutiveSamples` — generates adjacent samples for aggregation testing

## Code Conventions

- SwiftFormat config in `.swiftformat`: 2-space indentation, 100-char line limit, trailing commas on multi-element collections
- Mix of `snake_case` (some functions like `make_date_range_predicate`, `above_the_fold`) and `camelCase` — match surrounding code style
- `MARK` comments for section organization (e.g., `-MARK: Health Kit Constants`)
- `@Published` for reactive UI state, `@AppStorage` for persisted preferences
- Global constants at top of `ContentViewModel.swift`: `sample_cap`, `export_count`, `time_difference_large_enough`
- Global `logger` singleton in `Logger.swift` using `os.Logger`

## Known Constraints

- XLSX export uses libxlsxwriter C API directly (`workbook_new`, `worksheet_write_*`, etc.) — potential segfaults in edge cases
- `Set<HKQuantityTypeIdentifier>` persistence uses custom `RawRepresentable` conformance with JSON encoding (bottom of `ContentViewModel.swift`)
- Date range predicate only applied when range exceeds 1 day (`time_difference_large_enough`)
- 50,000 sample cap per export
- Category type export (sleep, symptoms, etc.) is defined in mappings but not yet wired into the export flow
