# AeroPass

A native SwiftUI iOS study app with question bank import, practice and mock exams, collections, notes, mind maps, a home-screen widget, and optional Qwen/DeepSeek assistance.

## Build

Open `aeropass.xcodeproj` in Xcode. The project uses Swift Package Manager to resolve CoreXLSX. Select your own development team if installing on a device.

No question bank is included. The app starts without questions; import your own `.xlsx` workbook in the app. The import screen explains the required columns. Question banks, spreadsheets, generated data, credentials and local build output are excluded from this repository.

AI features require users to provide their own Qwen or DeepSeek API key in the app settings. Keys are stored in the device Keychain. The optional daily quote request requires a separately provisioned `daily_quote_api_key` Keychain item; without one, the quote area stays empty. No API keys are distributed here.

## License

The source in this repository is licensed under GNU AGPL-3.0-only; see [LICENSE](../LICENSE). Question bank content and third-party services are not included in that grant.
