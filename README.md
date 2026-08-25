# LFM Vision

LFM Vision is a pair of Android and iOS sample apps that answer questions about
a photo on-device with LFM2.5-VL-450M through ZETIC.MLange.

```text
android/  Android Jetpack Compose app
ios/      iOS SwiftUI app
```

## Before you build

Both apps read `ZETIC_PERSONAL_KEY` from the repository-root `.env` file. Copy
the template and add a personal access key with access to the model:

```sh
cp .env.example .env
```

The `.env` file is ignored. Android compiles the key into `BuildConfig`, and
iOS embeds it in the application configuration, so do not distribute builds
that contain a personal key.

See [Android setup](android/README.md) and [iOS setup](ios/README.md) for
platform requirements and build commands.

## Contents

- [Release manifest](RELEASE-MANIFEST.md)
- [Third-party notices](THIRD_PARTY_NOTICES.md)
- [License](LICENSE)
