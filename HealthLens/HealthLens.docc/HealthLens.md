# ``HealthLens``

The missing export button for Apple Health.

@Metadata {
  @PageColor(blue)
}

## Overview

HealthLens is an open-source iOS app that exports your Apple Health data to **CSV** and **XLSX** formats for analysis outside the Health app. Whether you're tracking fitness progress in a spreadsheet, feeding data into a research pipeline, or just want a local backup, HealthLens gets your data out in seconds.

- **No account required** — open the app, pick your data, and share.
- **Completely offline** — your health data never leaves your device. No servers, no analytics, no tracking.
- **Open source** — inspect every line of code on [GitHub](https://github.com/wkaisertexas/HealthLens).

### Supported Health Categories

HealthLens can export data from across the Apple Health ecosystem:

| Category | Examples |
|---|---|
| Fitness | Steps, distance, active energy, cycling power & speed |
| Heart | Heart rate, HRV, resting heart rate, VO2 max |
| Body Measurements | Weight, BMI, body fat percentage, height |
| Mobility | Walking speed, stride length, stair speed, six-minute walk |
| Respiratory | Blood oxygen, respiratory rate, peak flow |
| Vital Signs | Blood glucose, body temperature |
| Nutrition | Macronutrients, vitamins, minerals, water intake |
| Hearing Health | Environmental & headphone audio exposure |
| Sleep | Sleep analysis stages |
| Symptoms | 40+ symptom categories from headache to mood changes |
| Reproductive Health | Menstrual cycles, ovulation, contraceptive tracking |

### Export Formats

**CSV** — Universal compatibility. Opens in Excel, Google Sheets, Numbers, R, Python, and virtually any data tool.

**XLSX** — Native Excel format with proper column typing, ready for pivot tables and formulas.

Exports include timestamps, values, units, source device, and metadata for each sample. Consecutive identical samples are automatically merged to keep file sizes manageable (up to 50,000 samples per export).

### Install

The recommended way to install HealthLens is from the [App Store](https://apps.apple.com/app/health-lens-csv-exporter/id6578440958).

## Topics

### Legal

- <doc:PRIVACY>
- <doc:LICENSE>

### Contributing

- <doc:README>
