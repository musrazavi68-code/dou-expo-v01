# Dou Expo 2.0 — Multiple Exposure Studio

A fresh Android-first Expo application, version **2.0.0**, built around the multi-layer compositing workflow inspired by BlendCamera. This is a clean V2 application scaffold and does not package the previous v1.3.0 project archive.

## V2 direction
- Multi-photo import and unlimited layer stack
- Live canvas composition with Normal, Multiply, Screen, Overlay, Soft Light, Hard Light, Darken, Lighten, Color Dodge, Difference, Color and Luminosity modes
- Opacity control, eight gradient directions, bright/dark luminance transparency
- Offline composition using the on-device WebView Canvas engine
- High-quality JPEG export to Android gallery or share sheet
- English/Persian language toggle
- Dark premium UI with adaptive React Native layout foundations
- Package ID: `com.mrazavi.douexpo.v2`

## Build locally
```bash
npm install
npx expo prebuild --platform android --non-interactive
cd android
./gradlew assembleDebug
```

## Build artifact
Push to `dou-expo-v2-blendcamera` or run the Android workflow manually. The APK is uploaded as `Dou-Expo-V2-Android-APK`.

## Developer
M.Razavi — Created by dou expo app

## Note
BlendCamera is a reference for workflow and feature ideas only. Dou Expo uses its own implementation and branding; it does not copy proprietary assets or source code.


## Build and development status

This branch targets Expo SDK 54 / React Native 0.81 and builds a debug APK with GitHub Actions.

### Included in the current prototype
- Two-exposure capture flow using the device camera, plus gallery import.
- 30 built-in stencil paths grouped by people, nature, abstract, architecture, objects and animals.
- Blend modes, opacity control, stencil / tint / white treatments.
- Color looks and draggable adjustment controls for exposure, contrast, highlights, shadows, temperature, tint, saturation and vibrance.
- Layer list, PNG export, gallery save/share and creator watermark.

### Build on GitHub
Push to `dou-expo-v2-blendcamera` or manually run **Dou Expo V2 Android APK** from the Actions tab. The workflow runs dependency installation, Expo validation, Android prebuild and Gradle debug assembly, then uploads `Dou-Expo-V2.1.0-Android-APK`.

### Planned next engineering stages
1. Subject-aware masks (person / animal / object segmentation) using an on-device segmentation model; this is not yet implemented in the current prototype.
2. Independent layer transforms and mask positioning.
3. High-resolution export and memory-safe processing for mid-range Android devices.
4. Responsive layout validation on phones, foldables and tablets.
5. Device testing for camera permissions, gallery access, export and sharing.

Do not treat the APK as release-ready until the latest Actions run succeeds and the exported APK has been installed and tested on physical devices.
