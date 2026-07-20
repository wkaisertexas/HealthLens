# HealthLens Testing and Async Export Refactor

## Scope

Refactor only the health-data export path. Selection, search, localization mappings, review UI,
the iOS 17.5 deployment target, Swift 5 language mode, and the CSV/XLSX schemas remain unchanged.

## Implementation sequence

1. Preserve the existing 49-test baseline and add 50,000-row CSV regression and scaling tests.
2. Introduce typed export requests, artifacts, records, errors, and injectable store/writer
   interfaces.
3. Replace callback orchestration, unsafe continuations, dispatch groups, and shared mutable query
   results with throwing structured concurrency.
4. Extract sample processing and CSV/XLSX generation from `ContentViewModel`.
5. Make deferred sharing throwing, remove forced unwraps, and present export failures in the UI.
6. Run fast and performance tests separately in CI and retain failure `.xcresult` bundles.

## Required behavior

- A failure for any requested type fails the complete export and cancels remaining queries.
- Empty successful queries produce a header-only file.
- Categories are ordered by identifier and samples by start date.
- Preferred units are used when compatible; compatible fallback units are otherwise used.
- Missing units, HealthKit failures, writer failures, and cancellation never produce partial
  artifacts.
- Export/review counters advance only after a file has been created successfully.
- Temporary output is removed after writer failure or cancellation.

## Verification

- Run the full unit suite after each production refactor stage.
- Keep the 50,000-row CSV export under 10 seconds and no more than 12 times the median 10,000-row
  export duration.
- Run performance tests separately and serially in CI.
- Before closing issue #33, manually export near the 50,000-sample cap on a physical device with
  “Save to Files” and record device, iOS version, sample count, duration, and output size.
