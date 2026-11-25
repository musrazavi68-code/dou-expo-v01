# Dou Expo — Beta 1.0.0

Android multi-exposure studio built with Expo / React Native.

- Splash / launcher screen with version label BETA 1.0.0
- Custom dark, frosted-glass D icon
- Multi-image import, editable layer list, visibility, reorder and opacity
- Canvas blend modes: Normal, Screen, Multiply, Overlay, Soft Light, Hard Light, Color Dodge, Difference, Darken, Lighten, Exclusion and Luminosity
- PNG export to gallery with share fallback
- Responsive phone / tablet layout

## Build
Requires Node 22, Java 17 and Android SDK.

```bash
npm install
npm run prebuild:android
cd android && ./gradlew assembleDebug
```

GitHub Actions builds a debug APK automatically when the beta branch is updated. This is a beta foundation; complete parity with BlendCamera is not claimed.
