# LFM Vision for Android

This Jetpack Compose app uses LFM2.5-VL-450M through
`com.zeticai.mlange:mlange:1.10.0` to answer questions about a selected or
captured photo on-device.

## Requirements

- Android Studio with a JDK 17-compatible Gradle environment.
- Android SDK Platform 34.
- A physical arm64 Android device running Android 7.0 (API 24) or later.
- A ZETIC.MLange personal access key with model access.

## Setup and build

From the repository root, copy `.env.example` to `.env` and set
`ZETIC_PERSONAL_KEY`:

```sh
cp .env.example .env
cd android
./gradlew :app:assembleDebug
```

The build reads only `ZETIC_PERSONAL_KEY`. The `.env` file is ignored, but the
key is compiled into `BuildConfig`; do not distribute an APK built with a real
key.

The default application ID is `com.zeticai.lfmvl.android`. Change it if it
conflicts with an application ID in your environment.

The app uses the system photo picker or camera capture, scales the selected
image to a 512-pixel maximum edge, and streams responses into the UI.
