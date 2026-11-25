# Dou Expo Beta 0.2.3 — Flutter

The Flutter implementation lives in `dou_expo_beta/`; the existing React Native app in `beta-app/` is preserved.

## v0.2.3
- Uses a persistent private release keystore. Every subsequent APK must use the same certificate so Android can install it as an update.
- Validates APK alignment, signature, pinned SHA-256 certificate fingerprint, package ID, version code 4, minimum SDK 24 and ARM64 native library.
- Version code incremented to 4. This key is new; uninstall earlier 0.2.1/0.2.2 builds once before installing this release.

## v0.2.0
- Live camera preview using the Flutter `camera` plugin, photo capture, and front/rear lens switching when available.
- Gallery image selection.
- Pattern bank, blend modes, opacity, eight gradient directions, aspect ratios, grid, and watermark.
- Final color-filter stage.
- PNG rendering from the on-screen composition with `RepaintBoundary.toImage` and `ui.ImageByteFormat.png`.
- Save rendered PNG bytes to the photo library using `gal`; share a real PNG file using `share_plus`.
- Camera and photo-library usage descriptions are applied by `tool/configure_permissions.py` after platform generation.

## Build locally
Requires Flutter 3.50.1 (Dart 3.14), Android API 24+ and Java 21 for CI; iOS builds require Xcode and iOS 13+.

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

## Launcher icon
Place the supplied icon image at `assets/icon/app_icon.png`, then run:
```bash
dart run flutter_launcher_icons
```
The icon source image has not yet been supplied in this repository, so icon generation is intentionally not run by CI.

## Export resolution note
The PNG is a real pixel render of the displayed editor canvas. High-resolution mode uses a 3x render scale (1.5x in standard mode); it is not yet a source-sensor-resolution, full-original-pixel compositor. The camera preview is a live view; the exported image is the composed canvas, not the raw camera sensor stream.

## Required GitHub Actions signing secrets
Before running the Android release workflow, add these repository secrets under Settings → Secrets and variables → Actions:
- `DOU_EXPO_KEYSTORE_BASE64`
- `DOU_EXPO_KEYSTORE_PASSWORD`
- `DOU_EXPO_KEY_ALIAS`
- `DOU_EXPO_KEY_PASSWORD`

Use the private keystore and values provided separately to the repository owner. Never commit the keystore or passwords to this public repository. The workflow fails intentionally if secrets are absent or the signing certificate fingerprint differs.

## Automated build
GitHub Actions pins Flutter 3.50.1, runs strict static analysis and tests, builds and verifies the persistently signed Android release APK, validates an unsigned iOS release build on macOS, and publishes the APK and clean source ZIP as artifacts.
