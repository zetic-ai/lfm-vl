# Aperçu for iOS

This SwiftUI app uses LFM2.5-VL-450M through ZETIC.MLange to answer questions
about a selected or captured photo on-device. Its French interface follows the
Bouygues Trilogy visual direction, with Bouygues fonts, navy functional actions,
a small yellow wordmark underline, and the full ZETIC footer logo.

## Requirements

- A physical iPhone for real model inference. The deployment target is iOS 18.0;
  the pinned internal SDK currently emits linker warnings about iOS 26.5 objects,
  so verify the supported OS/device combination before distributing a build.
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
answer. The first model download begins only after an explicit in-app approval;
later launches resume only that versioned approval.

## Session history

- Menu → Historique lists photos and conversations by most recent activity.
- One photo is one session. The archive begins with the first question, before
  inference starts; changing photos leaves the preceding session in history.
- A session opens for review. **Continuer la conversation** restores its photo and
  messages in the active chat. History remains readable when no model is
  downloaded or loaded.
- The full transcript stays in the archive. When runtime context must be rebuilt,
  only recent completed exchanges within a bounded token budget are replayed.
  Long conversations can therefore exceed what the model remembers.
- Streams are checkpointed every 0.5 seconds and at completion/backgrounding.
  A stream found after a process restart is marked interrupted; partial text stays.
- Files live under Application Support/ApercuSessions, outside the model cache,
  with iOS file protection and backup exclusion. Each session contains versioned
  JSON, an upright JPEG copy (longest edge at most 2048 px), and a 160 px thumbnail.
- Deleting a session deletes its photo and transcript. Clearing history requires
  confirmation. Removing the model does not remove history. Uninstalling the app
  removes its local archive; no account or synchronization is provided.
- Save failures are shown and prevent silently abandoning an unsaved session.
  Damaged or unknown-format records are preserved and reported, not overwritten.

## Validation

The Foundation-only archive and context tests run without the MLange SDK:

```sh
swift test --package-path ios/Packages/SessionHistory
```

The native UI also builds for Simulator. For interface-only inspection without
credentials or a model download, launch a Debug build with `-apercu-ui-testing`.
It seeds synthetic photo/chat fixtures in a separate `ApercuUITestSessions`
archive and opens history. This flag and fixture code are absent in Release.
It does not validate inference or context replay on a physical device.

Before release, check a real first question and follow-up, switch photos, stop an
answer, relaunch, review and continue an older session, and remove/re-download the
model while preserving history. Also check Dynamic Type and dark appearance.
