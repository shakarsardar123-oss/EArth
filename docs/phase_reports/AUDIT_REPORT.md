# 📋 ڕاپۆرتی پشکنینی تەواوی تایبەتمەندی Smart Wake Verification Alarm
## AURA Assistant — فێبرواری ٢٠٢٦

---

## 📊 پوختەی گشتی

| پێوانەکان | ئەنجام |
|---|---|
| **ڕێژەی تەواوبوون** | **٤٠٪** |
| فایلی سەرەکی ئاڵارم | ٢١ فایل |
| هەڵەی کۆمپایل (dart analyze) | ١٠ error + ٣٥ warning |
| تاقیکردنەوە | ٠ پاس / ١١ شکست (هیچ تاقیکردنەوەیەکی ئاڵارم نییە) |
| بنیاتنانی APK | شکست (Gradle plugin error) |
| هەڵەی کریتیکاڵ | ١٤ کێشەی گەورە |

---

## 🏁 ١٥ هەنگاوی پشکنین — دۆخی تەواو

### هەنگاو ١: مۆدێلی داتا (Data Model) — 🟡
- ✅ `WakeAlarm` class هەیە لە `domain/entities/alarm/wake_alarm.dart`
- ✅ `WakeVerificationConfig` هەیە لە `domain/entities/alarm/wake_verification_config.dart`
- ✅ `WakeVerificationState` enum هەیە لە `domain/entities/alarm/wake_verification_state.dart`
- ✅ `TimeOfDayData` هەیە لە هەمان فایل
- ❌ **invalid_constant** هەڵە: `static final _defaultCreatedAt` لە `const` constructor — `DateTime` ناتوانێت const بێت
- 🟡 `repeatDays` هەیە بۆ کۆنستراکتر بەڵام لە UI ناکارایە (وێجیت نییە)

### هەنگاو ٢: Provider/Riverpod چین — ❌
- ✅ `alarmSchedulerProvider` لە `alarm_scheduler_service.dart`
- ✅ `alarmAudioProvider` لە `alarm_audio_service.dart`
- ❌ **DUPLICATE PROVIDERS**: `alarm_providers.dart` دووبارە `alarmSchedulerProvider` و `alarmAudioProvider` پێناسە دەکات — لە کاتی کارپێکردنەوە conflct دروست دەکات
- ❌ `ref.read()` بۆ دروستکردنی سێrvices — گەر dependencies بگۆڕدرێن، سێrvices ناهێنرێتەوە
- ❌ `toolRegistryProvider` بەتاڵە — ٥ ئامرازی ئاڵارم تۆمار نەکراوە

### هەنگاو ٣: خزمەتگوزاری کاتی ئاڵارم (AlarmSchedulerService) — ❌
- ✅ `init()` `AndroidAlarmManager.initialize()` بانگ دەکات
- ✅ `scheduleAlarm()` ڕێکخستن بە `AndroidAlarmManager.oneShot` بەکاردەهێنێت
- ✅ `cancelAlarm()` و `snoozeAlarm()` شێوازەکان هەن
- ❌ **NO-ISOLATE BRIDGE (CRITICAL)**: `_alarmCallback()` no-op static method یە — `android_alarm_manager_plus` لە isolate جیاواز callback ئەکات بێدەستکاری Flutter UI. هیچ مکانیزمێک نییە بۆ bridge کردن بۆ `WakeVerificationService.triggerAlarm`. ئاڵارم بە بێدەنگی لە پشتەوە لێ دەدرێت بێ هیچ کاریگەرییەک.
- ❌ **argument_type_not_assignable**: `delayMs` (int) وەک `Duration` نێردراوە — `AndroidAlarmManager.oneShot` چاوەڕوای `Duration` دەکات نەک `int`

### هەنگاو ٤: خزمەتگوزاری دەنگ (AlarmAudioService) — 🟡
- ✅ `playAlarm()`, `stopAlarm()`, `setVolume()` شێوازەکان هەن
- ✅ `audioplayers` پاکێج بەکاردەهێنێت
- ✅ `gradualVolume` پشتگیری هەیە
- ❌ Unused import: `wake_verification_config.dart`
- 🟡 dead_null_aware_expression لە هێڵی ٤٩

### هەنگاو ٥: خزمەتگوزاری پشتڕاستکردنەوە (WakeVerificationService) — 🟡
- ✅ مەکینەی دۆخ (state machine) هەیە: `WakeVerificationStateMachine`
- ✅ `triggerAlarm()`, `verifyFace()`, `verifyVoice()`, `snooze()`, `dismiss()` هەن
- ❌ **TIGHT COUPLING**: `VoiceServiceImpl` ڕاستەوخۆ ئیمپۆرت کراوە نەک لە ڕێگەی provider/interface
- ❌ **DOUBLE SNOOZE**: `snooze()` هەم `Dart Timer` بۆ دووبارە-ئاگرتنی ئاڵارم بەکاردەهێنێت و هەم `scheduler.snoozeAlarm()` بۆ ڕێکخستن لە ڕێگەی `AndroidAlarmManager` — دووبارە-ڕێکخستن

### هەنگاو ٦: خزمەتگوزاری کامێرا (WakeCameraService) — ❌
- ✅ شێوازەکانی `startCamera()`, `stopCamera()`, `detectFaces()` هەن
- ✅ `camera` پاکێج بەکاردەهێنێت
- ✅ `google_mlkit_face_detection` بەکاردەهێنێت
- ❌ **5 COMPILE ERRORS**:
  - `metadata` پارامیتەری پێویست نییە لە `InputImage.fromBytes`
  - `inputImageData` ناوە پارامیتەرێک نییە
  - `InputImageData` میسۆد پێناسە نەکراوە
  - `InputImagePlaneMetadata` میسۆد پێناسە نەکراوە
  - `Uint8List` undefined — `import 'dart:typed_data'` نییە
- ❌ **Size class conflict**: `Size` custom class لەگەڵ `flutter/material.dart` Size冲突

### هەنگاو ٧: خزمەتگوزاری ئاگاداری (AlarmNotificationService) — 🟡
- ✅ `showAlarmNotification()`, `cancelNotification()` هەن
- ✅ `flutter_local_notifications` بەکاردەهێنێت
- ✅ `fullScreenIntent` پشتگیری هەیە
- ❌ **Int32List type mismatch**: `List<int>` ناتوانێت بۆ `Int32List?` بگۆڕدرێت
- ❌ `_onNotificationTap` no-op یە — گەشتکردن لەسەر بنەمای payload جێبەجێ نەکراوە

### هەنگاو ٨: شاشەی ئاڵارم (WakeAlarmScreen) — 🟡
- ✅ شاشەی تەواو هەیە بۆ دۆخی جیاوازی ئاڵارم
- ✅ `ConsumerWidget` بۆ Riverpod integration
- ✅ بەکارهێنانی `S.of(context)` بۆ localization
- 🟡 کامێرا پیشانویستی ئایکۆنی placeholder یە — `CameraPreview` وێجیت لە `WakeCameraService` بەستراوەتەوە
- ❌ `_RepeatDaysChips` هەمیشە لیستی بەتاڵ وەردەگرێت (شاراوە لە پشت snoozeDurationMinutes > 0)

### هەنگاو ٩: بەشی ڕێکخستن (AlarmSettingsSection) — 🟡
- ✅ وێجیت هەیە بۆ ڕێکخستنی ئاڵارم
- ✅ TimePicker, verification mode, snooze duration, sound selection
- ❌ Unused import: `aura_button.dart`
- ❌ `l10n` و `cs` unused local variables

### هەنگاو ١٠: لەبەرگرتنەوەی main_shell (MainShell) — ❌
- ✅ ٣ تابی هەیە: Dashboard, Voice, Settings
- ❌ **تابی چوارەم نییە**: تابی ئاڵارم زیاد نەکراوە بۆ BottomNavigationBar
- ❌ شاشەی WakeAlarmScreen لە ڕێگەی tab ناداتبینرێت — تەنها لە ڕێگەی ڕاوتکردن دەستپێبکات

### هەنگاو ١١: ناوەڕۆکی ئامرازەکان (ToolRegistry) — ❌
- ✅ `ToolRegistry` class هەیە لە `tool_registry.dart`
- ✅ ٥ ئامراز لە `phase3_connection_points.dart` پێناسە کراوە:
  - `set_alarm`, `cancel_alarm`, `snooze_alarm`, `dismiss_alarm`, `list_alarms`
- ❌ **ئامرازەکان تۆمار نەکراون**: `toolRegistryProvider` بەتاڵ `ToolRegistry()` دەگەڕێنێتەوە
- ❌ هیچ پەیوەندییەک نییە لە نێوان agent intent و ئامرازەکانی ئاڵارم

### هەنگاو ١٢: widgets.dart export — ❌
- ✅ `widgets.dart` هەیە وێجیتەکانی تر ئیکسپۆرت دەکات
- ❌ **alarm_settings_section.dart ئیکسپۆرت نییە** — دەبێت `export 'alarm_settings_section.dart';` زیاد بکرێت

### هەنگاو ١٣: ناوەڕۆکی localization — ✅
- ✅ ٤٥ کلی ئاڵارم لە `app_localizations.dart` (abstract class S)
- ✅ ٤٥ کلی لە `app_localizations_en.dart` (SEn) — بە تەواوی هاوتای بەردەست
- ✅ ٤٥ کلی لە `app_localizations_ku.dart` (SKu) — بە تەواوی هاوتای بەردەست
- ✅ S.of(context) بەکارهێنان لە شاشەکاندا
- ✅ دەقەکانی کوردی سۆرانی بەتەواوی وەرگێڕدراون

### هەنگاو ١٤: پەرمیشنەکانی ئەندرۆید — ✅
- ✅ `RECEIVE_BOOT_COMPLETED` هەیە
- ✅ `WAKE_LOCK` هەیە
- ✅ `USE_EXACT_ALARM` هەیە
- ✅ `CAMERA` هەیە
- ✅ `POST_NOTIFICATIONS` هەیە
- ✅ `USE_FULL_SCREEN_INTENT` هەیە
- ✅ `VIBRATE` هەیە
- ✅ `FOREGROUND_SERVICE` هەیە
- ❌ **AlarmWakeActivity** لە AndroidManifest.xml ڕاگەیەندراوە بەڵام هیچ پێکهاتەیەکی Kotlin/Java نییە — full-screen intent crash دەکات

### هەنگاو ١٥: بنیاتنانی ئەپ و ئامادەکاری — ❌
- ❌ **dart analyze**: ١٠ error، ٣٥ warning، ١٠٦ info — build ناکات
- ❌ **dart test**: ٠ پاس / ١١ شکست — هیچ تاقیکردنەوەیەکی تایبەت بە ئاڵارم نییە
- ❌ **flutter build apk --debug**: Gradle plugin failure (`Cannot run Project.afterEvaluate`)
- ❌ build.gradle هیچ config تایبەت بە ئاڵارم نییە (پێویست نییە بەڵام _AlarmWakeActivity missing_ کێشە دروست دەکات)

---

## 🔴 کێشە کریتیکاڵەکان (کە دەبێت چارەسەر بکرێن)

| # | کێشە | کاریگەری | فایل |
|---|---|---|---|
| ١ | **Isolate Bridge نییە** | ئاڵارم بە بێدەنگی لێ دەدرێت، هیچ پشتڕاستکردنەوەیەک ئەنجام نادرێت | `alarm_scheduler_service.dart:85` |
| ٢ | **AlarmWakeActivity نییە** | full-screen intent crash دەکات لە ئەندرۆید | `android/app/src/main/kotlin/` |
| ٣ | **٥ هەڵەی کۆمپایل لە WakeCameraService** | detectFaces() کاری ناکات — شیکردنەوەی ڕووخسار تەواو شکست دەهێنێت | `wake_camera_service.dart:145-190` |
| ٤ | **دووبارە Provider** | conflct لە کاتی کارپێکردنەوە بۆ alarmSchedulerProvider و alarmAudioProvider | `alarm_providers.dart` |
| ٥ | **Int32List type mismatch** | notification نانووسرێت | `alarm_notification_service.dart:87` |
| ٦ | **argument_type_not_assignable** | scheduleAlarm() و snoozeAlarm() کاری ناکەن — int ناتوانێت بۆ Duration بگۆڕدرێت | `alarm_scheduler_service.dart:40,114` |
| ٧ | **تابی ئاڵارم نییە** | بەکارهێنەر ناتوانێت بگات بە شاشەی ئاڵارم لە ڕێگەی UI سەرەکییەوە | `main_shell.dart` |
| ٨ | **ئامرازەکان تۆمار نەکراون** | agent intent ناتوانێت ئاڵارم کۆنتڕۆڵ بکات | `app_providers.dart` |
| ٩ | **double snooze** | دوو ئاڵارم لە کاتی یەکدا دواخراو لێ دەدرێت | `wake_verification_service.dart` |
| ١٠ | **_onNotificationTap no-op** | خستنەسەر ئاڵارم لە ڕێگەی notification کاری ناکات | `alarm_notification_service.dart` |

---

## 🟡 کێشە ناوەندییەکان

| # | کێشە | فایل |
|---|---|---|
| ١ | Tight coupling: VoiceServiceImpl ڕاستەوخۆ ئیمپۆرت | `wake_verification_service.dart` |
| ٢ | _RepeatDaysChips هەمیشە لیستی بەتاڵ وەردەگرێت | `wake_alarm_screen.dart` |
| ٣ | alarm_settings_section.dart لە widgets.dart ئیکسپۆرت نییە | `widgets.dart` |
| ٤ | Camera preview placeholder — هیچ کامێرایەک پیشان نادرێت | `wake_alarm_screen.dart` |
| ٥ | Size class conflict لەگەڵ Flutter material | `wake_camera_service.dart` |
| ٦ | invalid_constant لە WakeAlarm (static DateTime) | `wake_alarm.dart:14` |
| ٧ | Unused imports و variables | چەندین فایل |

---

## ✅ ئەو بەشانەی کە تەواون

| بەش | وردەکاری |
|---|---|
| Localization (٤٥ کلی) | هەموو کلیەکان بە ئینگلیزی و کوردی سۆرانی جێبەجێ کراون |
| پەرمیشنەکانی ئەندرۆید | ٨ پەرمیشنی پێویست تەواو ڕاگەیەندراون |
| مۆدێلی داتا | WakeAlarm, WakeVerificationConfig, WakeVerificationState هەن |
| State Machine | WakeVerificationStateMachine پێناسە کراوە |
| ڕێکخستنی ئاڵارم | scheduleAlarm, cancelAlarm, snoozeAlarm شێوازەکان هەن |
| دەنگی ئاڵارم | AlarmAudioService بە gradual volume |
| فایلی P3 Connection Points | ٥ ئامراز پێناسە کراون (بەڵام تۆمار نەکراون) |

---

## 📈 خشتەی دۆخی ١٥ هەنگاو

| هەنگاو | وەسف | دۆخ | ڕێژە |
|---|---|---|---|
| ١ | مۆدێلی داتا | 🟡 | ٧٥٪ |
| ٢ | Provider/Riverpod چین | ❌ | ٢٥٪ |
| ٣ | خزمەتگوزاری کاتی ئاڵارم | ❌ | ٣٠٪ |
| ٤ | خزمەتگوزاری دەنگ | 🟡 | ٧٥٪ |
| ٥ | خزمەتگوزاری پشتڕاستکردنەوە | 🟡 | ٦٠٪ |
| ٦ | خزمەتگوزاری کامێرا | ❌ | ٢٠٪ |
| ٧ | خزمەتگوزاری ئاگاداری | 🟡 | ٥٥٪ |
| ٨ | شاشەی ئاڵارم | 🟡 | ٥٠٪ |
| ٩ | بەشی ڕێکخستن | 🟡 | ٦٠٪ |
| ١٠ | لەبەرگرتنەوەی main_shell | ❌ | ٢٠٪ |
| ١١ | ناوەڕۆکی ئامرازەکان | ❌ | ١٠٪ |
| ١٢ | widgets.dart export | ❌ | ٠٪ |
| ١٣ | localization | ✅ | ١٠٠٪ |
| ١٤ | پەرمیشنەکانی ئەندرۆید | 🟡 | ٨٠٪ |
| ١٥ | بنیاتنانی ئەپ و ئامادەکاری | ❌ | ٥٪ |


**ڕێژەی تەواوبوونی گشتی: ٤٠٪**

---

## 🔧 ئەنجامی کۆد ئەنالیز

```
dart analyze lib/ — ١٥١ کێشە:
  ❌ ١٠ error
  ⚠️ ٣٥ warning
  ℹ️ ١٠٦ info

Error-kan:
  - alarm_scheduler_service.dart:40 — int → Duration type mismatch
  - alarm_scheduler_service.dart:114 — int → Duration type mismatch
  - wake_alarm.dart:14 — invalid_constant
  - wake_camera_service.dart:145 — missing required parameter 'metadata'
  - wake_camera_service.dart:147 — undefined named parameter 'inputImageData'
  - wake_camera_service.dart:147 — undefined method 'InputImageData'
  - wake_camera_service.dart:152 — undefined method 'InputImagePlaneMetadata'
  - wake_camera_service.dart:185 — undefined class 'Uint8List'
  - wake_camera_service.dart:190 — undefined identifier 'Uint8List'
  - alarm_notification_service.dart:87 — List<int> → Int32List? mismatch

dart test — ٠ پاس / ١١ شکست (هیچ تاقیکردنەوەی تایبەت بە ئاڵارم نییە)

flutter build apk --debug — شکست:
  Gradle plugin error: 'Cannot run Project.afterEvaluate(Closure) when the project is already evaluated'
```

---

## 🗂️ پشکنینی پشتگیری لە پاکێجەکان

| پاکێج | پێویست | بەردەست لە pubspec.yaml |
|---|---|---|
| android_alarm_manager_plus | ✅ | ✅ |
| audioplayers | ✅ | ✅ |
| camera | ✅ | ✅ |
| google_mlkit_face_detection | ✅ | ✅ |
| flutter_local_notifications | ✅ | ✅ |
| shared_preferences | ✅ | ✅ |
| vibration | ✅ | ✅ |
| flutter_riverpod | ✅ | ✅ |

---

## 📝 کۆتایی

تایبەتمەندی Smart Wake Verification Alarm لە ئاستی ئێستادا **٤٠٪ تەواو**ە. هەرچەندە پێکهاتەی سەرەکی (مۆدێلی داتا، state machine، localization) بەتەواوی هەن، بەڵام **١٤ کێشەی کریتیکاڵ و ناوەندی** هەن کە ڕێگری دەکەن لە کارپێکردنی تایبەتمەندییەکە. بەتایبەتی:

١. **Isolate bridge** نییە — ئەمە گرنگترین کێشەیە چونکە بێ ئەمە ئاڵارم بەتەواوی بێهۆیە
٢. **AlarmWakeActivity** نییە — full-screen intent crash دەکات
٣. **٥ هەڵەی کۆمپایل لە WakeCameraService** — شیکردنەوەی ڕووخسار ناکارایە
٤. **تابی ئاڵارم لە UI سەرەکی نییە** — بەکارهێنەر ناتوانێت بگات بۆ ئاڵارم

بێ چارەسەرکردنی ئەم کێشانە، ئەپەکە ناتوانێت build بکات و تایبەتمەندییەکە بەتەواوی ناکارایە.
