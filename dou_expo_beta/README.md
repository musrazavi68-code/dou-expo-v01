# Dou Expo Beta 0.2.0 — Flutter

The Flutter implementation lives in `dou_expo_beta/`; the existing React Native app in `beta-app/` is preserved.

## v0.2.0
- Live camera preview using the Flutter `camera` plugin, photo capture, and front/rear lens switching when available.
- Gallery image selection.
- Pattern bank, blend modes, opacity, eight gradient directions, aspect ratios, grid, and watermark.
- Final color-filter stage.
- PNG rendering from the on-screen composition with `RepaintBoundary.toImage` and `ui.ImageByteFormat.png`.
- Save rendered PNG bytes to the photo library using `gal`; share a real PNG file using `share_plus`.
- Camera and photo-library usage descriptions are applied by `tool/configure_permissions.py` after platform generation.

## Build locally
Requires Flutter stable with Dart SDK >= 3.12.0, Android SDK, and (for iOS) Xcode.

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
The PNG is a real pixel render of the displayed editor canvas. High-resolution mode uses a 3x render scale (1.5x in standard mode); it is not yet a source-sensor-resolution, full-original-pixel compositor.

## Automated build
GitHub Actions runs dependency resolution, static analysis, tests, release APK compilation, and publishes both the APK and source ZIP as workflow artifacts.
