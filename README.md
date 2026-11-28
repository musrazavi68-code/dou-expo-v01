# Dou Expo 2.3.0 — Multiple Exposure Studio

بازسازی بر پایه آخرین سورس موفق و APK تأییدشده در Actions (نسخه 2.2.2، اجرای #50، commit مبنا `f4e1c2e1b395c2b428c653927c33339d8468bb96`). این شاخه نسخه مستقل بازسازی‌شده 2.3.0 است.

## شناسه و سازگاری
- Version: 2.3.0
- Android versionCode: 25
- Application ID: `com.mrazavi.douexpo.v2`
- Minimum Android: 8.0 / API 26
- Expo SDK 54 / React Native 0.81
- Android ABIs: armeabi-v7a و arm64-v8a

## امکانات موجود در سورس مبنا
- ثبت تک‌نوردهی مستقل یا گردش کار دو نوردهی با دوربین؛ انتخاب چندین تصویر از گالری و افزودن لایه‌های بیشتر، تابع حافظهٔ دستگاه است
- ترکیب دو تصویر و لایه‌ها با حالت‌های Normal, Screen, Lighten, Multiply, Overlay, Soft Light, Hard Light, Darken, Color Dodge, Difference, Exclusion و Luminosity
- کنترل opacity، گرادیان ۸ جهته، شفافیت وابسته به روشنایی (Bright/Dark) و پیش‌نمایش زنده Canvas در WebView
- مرتب‌سازی لایه‌ها با کنترل لمسی بالا/پایین و حذف لایه با انیمیشن
- رابط واکنش‌گرا برای موبایل، حالت افقی، تبلت و نمایشگر عریض گوشی‌های تاشو؛ تغییر اندازه در زمان باز/بسته شدن نمایشگر
- 30 ماسک برداری آماده در دسته‌های انسان، طبیعت، انتزاعی، معماری، اشیا و حیوانات
- حالت‌های stencil، tint و white برای ماسک
- تنظیمات exposure، contrast، highlights، shadows، temperature، tint، saturation و vibrance
- بازیابی خودکار آخرین وضعیت پروژه پس از بسته‌شدن ناگهانی، شامل حالت ثبت، زوم و وضعیت نوردهی اول
- خروجی گرفتن از نسخه پشتیبان JSON و واردکردن دوباره پروژه با لایه‌ها و تنظیمات ویرایش
- ذخیره در گالری و اشتراک‌گذاری
- رابط فارسی/انگلیسی، هویت بصری مینیمال و نشان گرافیکی اختصاصی، بازخورد لمسی و انیمیشن‌های انتقال

## دارایی‌ها و داده‌ها
- کتابخانه 50 پترن مستقل در `design_assets/Dou_Expo_Pattern_Library_50_v1.3.0.zip`
- فایل Figma و Graphics Kit در Release اصلی مخزن باقی می‌مانند.
- APK مرجع نسخه 2.2.2 از اجرای موفق #50 است؛ برای نسخه 2.3.0 باید workflow همین شاخه اجرا شود.

## Build
```bash
npm install
npx expo install --check
npx expo export --platform android --output-dir dist-check
CI=1 npx expo prebuild --platform android --clean
cd android
./gradlew assembleDebug
```

## GitHub Actions و Release
Push به شاخه `dou-expo-v2.3.0-rebuild` ساخت APK و آزمون‌های سازگاری را اجرا می‌کند. Push تگ `v2.3.0` پس از ساخت موفق، Release می‌سازد و APK آزمایشی و checksum را به آن متصل می‌کند.

## اصلاحات شاخه duo-shot-android-v4
- افزودن حالت ثبت تک‌نوردهی در کنار دابل‌اکسپوژر
- افزودن واردسازی نسخه پشتیبان پروژه JSON با اعتبارسنجی ساختار و لایه‌های Base64
- تکمیل Snapshot بازیابی خودکار و Undo/Redo برای وضعیت گردش ثبت
- فعال‌سازی تبدیل مستقل لایه پایه در موتور Canvas و اصلاح انتخاب لایه پس از حذف
- افزودن وابستگی رسمی Expo Document Picker برای بارگذاری فایل پروژه

## محدوده‌ای که هنوز کامل/تأیید نشده
ماسک هوشمند segmentation، جابه‌جایی/چرخش/تغییر اندازه مستقل هر لایه و خروجی Release امضاشده در سورس مبنا تأیید نشده‌اند. این موارد را به‌عنوان قابلیت حاضر معرفی نمی‌کنیم. APK نسخه جدید فقط پس از اجرای موفق Actions و نصب روی دستگاه واقعی قابل تأیید است.

## Developer
M.Razavi — Created by dou expo app
