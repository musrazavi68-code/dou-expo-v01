# Dou Expo Beta 0.2.4 — Flutter

The Flutter implementation lives in `dou_expo_beta/`; the existing React Native app in `beta-app/` is preserved.

## Current verified build

- App version: `0.2.4+5`
- Android application ID: `com.douexpo.dou_expo_beta`
- Minimum Android SDK: 24; target SDK: 36.
- Release APK includes ARM, ARM64 and x86_64 native targets.
- Latest verified CI passed Flutter analysis, automated tests, Android release build, APK alignment/signature/package checks, Android API 35 emulator installation and launch, and unsigned iOS release compilation.
- The automated suite contains 31 tests (30 unit tests plus one widget navigation test).

Latest verified run: https://github.com/musrazavi68-code/dou-expo-v01/actions/runs/45890652374

## Signing status — important

The latest CI APK is **TEST-ONLY and signed with a temporary CI key** because the repository signing secrets were empty at build time. It installs as a fresh app, but a later build signed with a different key cannot update it.

For a stable release/update path, the repository owner must configure these GitHub Actions secrets with the **original persistent keystore and its exact credentials**:

- `DOU_EXPO_KEYSTORE_BASE64`
- `DOU_EXPO_KEYSTORE_PASSWORD`
- `DOU_EXPO_KEY_ALIAS`
- `DOU_EXPO_KEY_PASSWORD`

Never commit a keystore or password to the repository. Do not uninstall an existing app just to work around a signature mismatch if its local project data matters. The previous signing key cannot be reconstructed from an APK or its public certificate fingerprint.

## Features

- Live camera preview, photo capture and front/rear lens switching when supported.
- Gallery image selection.
- Double-exposure composition with blend modes, opacity, exposure, transforms, masks and stencils.
- Darkroom color adjustments and film-style camera recipes.
- PNG rendering/export and sharing.
- Shared project session across the three studio modes, project asset storage, debounced autosave, lifecycle flush, and session undo/redo history.

## Known product limitations / device QA

- The camera driver exposes exposure compensation and tap-to-focus; ISO and shutter speed are not currently exposed.
- High-resolution export renders the composition canvas; it is not a raw sensor-resolution compositor.
- CI emulator success is not a substitute for testing camera, gallery permissions, export and sharing on physical Android devices and iPhones.
- A launcher icon source image has not yet been supplied at `assets/icon/app_icon.png`; CI intentionally does not generate launcher icons.

## Build locally

Requires Flutter 3.50.1 (Dart 3.14), Android API 24+ and Java 21 for Android; iOS builds require Xcode and iOS 13+.

```bash
cd dou_expo_beta
flutter create --platforms=android,ios --project-name dou_expo_beta --org com.douexpo .
python3 tool/configure_permissions.py
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

APK: `build/app/outputs/flutter-apk/app-release.apk`

## Automated regression / build pipeline

GitHub Actions runs on pushes to the beta branch, pull requests targeting it, nightly, or manual dispatch. It pins Flutter 3.50.1, runs static analysis and tests, builds and verifies the Android APK, attempts an API 35 emulator install/launch smoke test, builds iOS without code signing, and publishes APK/source artifacts. The emulator smoke step is non-blocking on hosted runners that cannot boot an emulator; its individual result must still be inspected before treating device smoke as passed.
