# تطبيق المصطفى

> التطبيق الرسمي لموقع [almostfa.site](https://almostfa.site)

تطبيق أندرويد احترافي يعرض موقع almostfa.site في وضع ملء الشاشة بدون أي عناصر إضافية.

---

## المميزات

- **عرض ملء الشاشة** — الموقع يظهر بالكامل بدون هيدر أو شريط تنقل
- **Pull to Refresh** — اسحب للأسفل لتحديث الصفحة
- **شاشة تحميل متحركة** — أنيميشن أخضر مع شريط تقدم ونسبة مئوية
- **شريط تقدم** — يظهر أعلى الشاشة أثناء تحميل الصفحات
- **شاشة خطأ** — عند انقطاع الإنترنت مع زر إعادة المحاولة
- **إعادة اتصال تلقائي** — يعيد التحميل تلقائياً عند عودة الإنترنت
- **زر رجوع ذكي** — يرجع في تاريخ التصفح ثم يطلب تأكيد الخروج
- **Haptic Feedback** — اهتزاز خفيف عند التفاعل
- **ProGuard** — تقليص حجم التطبيق في الإصدار النهائي
- **Adaptive Icon** — أيقونة تكيفية لجميع أجهزة أندرويد

---

## متطلبات البناء

- **Flutter** 3.24.0+
- **Dart** 3.0.0+
- **Java** 17+
- **Android minSdk** 21 (Android 5.0+)

---

## البناء محلياً

```bash
# تثبيت الحزم
flutter pub get

# توليد الأيقونات (بعد وضع app_icon.png)
dart run flutter_launcher_icons

# بناء APK
flutter build apk --release

# بناء AAB لـ Google Play
flutter build appbundle --release
```

## البناء عبر GitHub Actions

1. ارفع المشروع على GitHub
2. اذهب إلى **Actions** > سيبدأ البناء تلقائياً عند Push إلى `main`
3. حمّل APK و AAB من **Artifacts**
4. للنشر التلقائي: أنشئ Tag بصيغة `v1.0.0` وسيُنشأ Release تلقائياً

---

## إضافة أيقونة التطبيق

1. ضع ملف PNG باسم `app_icon.png` بحجم **1024x1024** بكسل في المجلد:
   ```
   assets/icon/app_icon.png
   ```
2. شغّل الأمر:
   ```bash
   dart run flutter_launcher_icons
   ```
3. سيتم توليد جميع أحجام الأيقونات تلقائياً بما فيها Adaptive Icon

> الأيقونة ستظهر على خلفية خضراء داكنة (`#074424`) في الأجهزة التي تدعم Adaptive Icon.

---

## هيكل المشروع

```
almostfa_app/
├── .github/workflows/
│   └── build-android.yml         # GitHub Actions CI/CD
├── android/
│   ├── app/
│   │   ├── build.gradle          # إعدادات البناء
│   │   ├── proguard-rules.pro    # قواعد ProGuard
│   │   └── src/main/
│   │       ├── AndroidManifest.xml
│   │       ├── kotlin/.../MainActivity.kt
│   │       └── res/              # الموارد والأنماط
│   ├── build.gradle
│   └── settings.gradle
├── assets/icon/                  # ضع app_icon.png هنا
├── lib/
│   ├── main.dart                 # نقطة البداية
│   └── webview_screen.dart       # شاشة WebView
├── .gitignore
├── pubspec.yaml
└── README.md
```

---

## توقيع التطبيق (Release Signing)

لنشر التطبيق على Google Play:

1. أنشئ Keystore:
   ```bash
   keytool -genkey -v -keystore almostfa-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias almostfa
   ```

2. أنشئ ملف `android/key.properties`:
   ```properties
   storePassword=YOUR_STORE_PASSWORD
   keyPassword=YOUR_KEY_PASSWORD
   keyAlias=almostfa
   storeFile=../almostfa-release.jks
   ```

3. ابنِ النسخة:
   ```bash
   flutter build apk --release
   flutter build appbundle --release
   ```

---

## الحزم المستخدمة

| الحزمة | الاستخدام |
|--------|-----------|
| webview_flutter | عرض الموقع |
| webview_flutter_android | دعم أندرويد |
| connectivity_plus | مراقبة الشبكة |
| flutter_spinkit | أنيميشن التحميل |
| flutter_launcher_icons | توليد الأيقونات |

---

جميع الحقوق محفوظة - المصطفى
