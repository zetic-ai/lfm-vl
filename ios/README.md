# LFM Vision for iOS

This SwiftUI app uses LFM2.5-VL-450M through ZETIC.MLange to answer questions
about a selected or captured photo on-device.

## Requirements

- A physical iPhone running iOS 18.0 or later. The included SDK package does
  not support the iOS Simulator.
- Xcode 16 or later.
- A ZETIC.MLange personal access key with model access.
- Sufficient device storage for the initial model download.

## Setup and run

1. At the repository root, copy `.env.example` to `.env` and set
   `ZETIC_PERSONAL_KEY`.

   ```sh
   cp .env.example .env
   ./ios/scripts/generate-secrets-xcconfig.sh
   ```

   `Secrets.xcconfig` is generated locally and ignored by Git. Its value is
   embedded in the app, so do not share a signed build containing a real key.

2. Open `ios/ZeticMLangeLLMSample.xcodeproj` in Xcode.
3. Select your signing team and, if required by your environment, change the
   bundle identifier from `com.zeticai.lfmvl`.
4. Select a physical device and run the `ZeticMLangeLLMSample` scheme.

For a command-line build without code signing:

```sh
cd ios
xcodebuild -project ZeticMLangeLLMSample.xcodeproj \
  -scheme ZeticMLangeLLMSample \
  -destination generic/platform=iOS \
  CODE_SIGNING_ALLOWED=NO build
```

The project includes `OTHER_LDFLAGS = -framework Accelerate`, which is needed
by the SDK package.

## Runtime behavior

Follow-up questions about the same photo retain model context. When a different
photo is selected, the app clears model context before generating its next
answer.
