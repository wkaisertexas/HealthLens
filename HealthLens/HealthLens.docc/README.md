# Contributing

How to set up HealthLens for local development and contribute to the project.

## Local Development

Clone the repository and open it in Xcode:

```bash
git clone https://github.com/wkaisertexas/HealthLens
cd HealthLens
open HealthLens.xcodeproj
```

HealthLens uses an Xcode project (not Swift Package Manager) with two dependencies:

- **HealthKit** — system framework for reading health data
- **libxlsxwriter** — SPM package for XLSX file generation

Ensure you have a valid signing identity configured in Xcode. HealthKit requires the HealthKit entitlement and a provisioning profile, so you'll need to update the bundle identifier and team for local builds.

### Running Tests

Tests run on the iOS Simulator (HealthKit types cannot be instantiated without it):

```bash
xcodebuild test -scheme HealthLens
```

To run a single test:

```bash
xcodebuild test -scheme HealthLens \
  -only-testing:HealthLensTests/HealthLensTests/testCSVSanitization
```

## How to Contribute

- [Open an issue](https://github.com/wkaisertexas/HealthLens/issues) if you find a bug or have a feature request.
- [Submit a pull request](https://github.com/wkaisertexas/HealthLens/pulls) for code changes.

### Code Style

The project uses SwiftFormat with a `.swiftformat` config at the repo root: 2-space indentation, 100-character line limit, and trailing commas on multi-element collections. Run SwiftFormat before opening a PR.

## License

HealthLens is open-source under the [CC BY-NC 4.0 License](https://creativecommons.org/licenses/by-nc/4.0/).
