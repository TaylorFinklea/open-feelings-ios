# Open Feelings

Open Feelings is a free, open-source iOS app for naming and logging emotions.
It keeps data on device, syncs through the user's private iCloud database, and
does not use accounts, ads, analytics, or third-party SDKs.

## Features

- Complete three-ring emotion wheel adapted from Open Emotion Wheel v1.1.
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

The app targets iOS 26.0. The original Swift source code is licensed under MIT.

## Licensing and Attribution

The Swift source code is MIT licensed. The emotion taxonomy is adapted from
Open Emotion Wheel v1.1 by David Thorpe, openemotionwheel.com, and is licensed
under CC BY-SA 4.0. See `ATTRIBUTION.md` and `DATA-LICENSE.md`.
