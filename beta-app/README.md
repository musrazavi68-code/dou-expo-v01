# Dou Expo — Beta 1.0.1

Android multi-exposure studio built with Expo / React Native.

## Beta 1.0.1 fixes
- Release APK build (not Metro-dependent debug APK).
- Gradle release task embeds the React Native JavaScript bundle in the APK.
- CI verifies the embedded bundle before publishing the APK artifact.
- Android versionCode incremented to 2 for in-place upgrade.
- Launcher and splash assets are generated before native prebuild.

## Current editor foundation
- Multi-image import and editable layer list.
- Layer visibility and opacity controls.
- Canvas blend modes: Normal, Screen, Multiply, Overlay, Soft Light, Hard Light, Color Dodge, Difference, Darken, Lighten, Exclusion and Luminosity.
- PNG export to gallery with share fallback.
- Responsive phone / tablet layout.

## Build
Requires Node 22, Java 17 and Android SDK.

```bash
npm install
npm run android:release
```

GitHub Actions builds a standalone release APK when this branch is updated. The workflow checks that the React Native bundle is present inside the APK; this prevents shipping a Metro-dependent debug build by mistake.
