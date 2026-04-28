# Open Feelings

Open Feelings is a free, open-source iOS app for naming and logging emotions.
It keeps data on device, syncs through the user's private iCloud database, and
does not use accounts, ads, analytics, or third-party SDKs.

## Features

- Complete three-ring emotion wheel with no blank sectors.
- Guided three-step check-in flow for people who find the full wheel overwhelming.
- SwiftData persistence with optional CloudKit private database sync.
- Optional Face ID, Touch ID, or device passcode app lock.
- Optional local reminder notifications.
- Optional write-only Apple Health State of Mind integration.
- CSV and JSON export from history.

## Development

This project uses XcodeGen to generate the Xcode project:

```sh
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
```

The app targets iOS 26.0 and is licensed under MIT, including the original
emotion taxonomy.
