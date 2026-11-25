# Dou Expo Beta — Flutter build

این پروژه Flutter در پوشه مستقل `dou_expo_beta/` قرار دارد تا نسخه React Native قبلی در `beta-app/` بدون تغییر باقی بماند.

## Build
نیازمند Flutter stable و Android SDK:
```bash
cd dou_expo_beta
flutter pub get
flutter build apk --release
```

خروجی: `build/app/outputs/flutter-apk/app-release.apk`

## قابلیت‌های این پایه
- انتخاب عکس از گالری یا دوربین
- بانک پترن دسته‌بندی‌شده با انتخاب تصادفی
- ترکیب بصری پترن، تغییر BlendMode با سوایپ و کنترل شفافیت
- ۸ جهت گرادیان و نسبت تصویر 1:1، 3:2 و 4:3
- فیلترهای پایانی، گرید و واترمارک
- ثبت خروجی بوم در گالری و اشتراک‌گذاری
- چیدمان واکنش‌گرا برای موبایل و نمایشگرهای عریض

توجه: پترن‌های این نسخه پایه گرادیانی هستند؛ بانک بافت‌های تصویری واقعی و ماسک مستقل لایه‌ها مرحله توسعه بعدی است.


Build workflow: `.github/workflows/dou-expo-flutter.yml` — release APK is published as a GitHub Actions artifact after successful analysis and compilation.
