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
