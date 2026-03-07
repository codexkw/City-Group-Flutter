# CLAUDE.md — City Group Flutter App

> **This file is the single source of truth for Claude Code in this repo. Read it fully before every task.**

---

## 📖 REQUIRED READING — DO THIS FIRST

**Before starting ANY work, run:**
```bash
cat CLAUDE.md
cat TASKS.md
cat docs/API_CONTRACTS.md
```

**The API_CONTRACTS.md is your specification for every screen.**
**Never assume an endpoint shape — always read the contract first.**

---

## 🔒 OPERATING RULES (ALWAYS ENFORCED)

### Rule 1: Check API Contract Before Building Any Screen

Before writing any screen or repository class:
1. Open `docs/API_CONTRACTS.md`
2. Find the endpoint(s) this screen uses
3. Match request/response shapes exactly — field names, types, nesting
4. Never hardcode URLs — always use `ApiConstants`

### Rule 2: Task Tracking in TASKS.md

```
[ ]  — Not started
[⏳] — In progress
[✅] — Completed (YYYY-MM-DD)
[❌] — Blocked (reason — e.g. "API endpoint not ready yet")
[⏸️] — Paused
```

Before starting a task → `[⏳]`
After completing → `[✅] YYYY-MM-DD`
If the API endpoint is not live yet → `[❌] API not ready`

### Rule 3: Never Start a Flutter Screen If the API Endpoint Is Not Ready

Check `docs/API_CONTRACTS.md`. If the endpoint is not yet implemented on the backend, mark the task `[❌] API not ready` and move to the next one.

### Rule 4: Build Verification After Every Screen

```bash
flutter analyze          # must pass with zero errors
flutter test             # must pass
flutter build apk        # verify it compiles
```

Never mark a task `[✅]` with analyzer errors.

### Rule 5: Test Every Screen in All 3 Languages

```bash
# Run app in each locale and verify layout
# Arabic = RTL, must test every screen flips correctly
# Hindi = Devanagari font must render
```

All UI strings come from ARB files — zero hardcoded strings allowed.

### Rule 6: Git Branching

**Never commit to `master` directly.**

```bash
git checkout master && git pull origin master
git checkout -b feature/{screen-name}

# Work → analyze → test → commit
git add . && git commit -m "feat(auth): implement login screen"
git push origin feature/{screen-name}
```

Branch naming:
```
feature/auth-login
feature/auth-biometric
feature/auth-forgot-password
feature/home-screen
feature/check-in
feature/check-out
feature/attendance-history
feature/task-list
feature/task-detail
feature/task-pause-reason
feature/task-complete
feature/notifications
feature/profile
feature/language-settings
feature/speed-monitoring
```

---

## 📁 PROJECT STRUCTURE

```
City-Group-Flutter/
├── CLAUDE.md                          ← THIS FILE
├── TASKS.md                           ← Task tracker
├── docs/
│   └── API_CONTRACTS.md               ← API ↔ Flutter contract (read before every screen)
├── pubspec.yaml
├── l10n.yaml
├── .github/
│   └── workflows/
│       └── deploy-flutter.yml
└── lib/
    ├── main.dart
    ├── l10n/
    │   ├── app_en.arb
    │   ├── app_ar.arb
    │   └── app_hi.arb
    └── core/
    │   ├── constants/
    │   │   └── api_constants.dart
    │   ├── api/
    │   │   └── api_client.dart
    │   ├── theme/
    │   │   └── app_theme.dart
    │   └── router/
    │       └── app_router.dart
    └── features/
        ├── auth/
        │   ├── data/
        │   │   └── auth_repository.dart
        │   └── presentation/
        │       ├── providers/
        │       │   └── auth_provider.dart
        │       └── screens/
        │           ├── login_screen.dart
        │           ├── biometric_screen.dart
        │           └── forgot_password_screen.dart
        ├── attendance/
        │   ├── data/
        │   │   └── attendance_repository.dart
        │   └── presentation/
        │       ├── providers/
        │       └── screens/
        │           ├── check_in_screen.dart
        │           ├── check_out_screen.dart
        │           └── attendance_history_screen.dart
        ├── tasks/
        │   ├── data/
        │   │   └── task_repository.dart
        │   └── presentation/
        │       ├── providers/
        │       └── screens/
        │           ├── task_list_screen.dart
        │           ├── task_detail_screen.dart
        │           ├── pause_reason_bottom_sheet.dart
        │           └── task_complete_modal.dart
        ├── home/
        │   └── presentation/
        │       └── screens/
        │           └── home_screen.dart
        ├── notifications/
        │   ├── data/
        │   │   └── notifications_repository.dart
        │   └── presentation/
        │       └── screens/
        │           └── notifications_screen.dart
        ├── profile/
        │   ├── data/
        │   │   └── profile_repository.dart
        │   └── presentation/
        │       └── screens/
        │           ├── profile_screen.dart
        │           ├── language_settings_screen.dart
        │           └── change_password_screen.dart
        └── speed_monitor/
            └── services/
                └── background_speed_service.dart
```

---

## 🌐 URLS & CONNECTION

| | Value |
|-|-------|
| **API Base URL** | `https://api-city-group.codexkw.co/api/v1` |
| **Admin Panel** | `https://city-group.codexkw.co/` |
| **Backend Repo** | `https://github.com/codexkw/City-Group.git` |
| **Flutter Repo** | `https://github.com/codexkw/City-Group-Flutter.git` |

---

## 🛠️ TECH STACK

| Component | Package |
|-----------|---------|
| State management | `flutter_riverpod` |
| HTTP client | `dio` + JWT interceptor in `api_client.dart` |
| Navigation | `go_router` |
| GPS | `geolocator` |
| Camera | `camera` + `image_picker` |
| Biometric | `local_auth` |
| Push notifications | `firebase_messaging` |
| Background service | `flutter_background_service` |
| Secure storage (JWT) | `flutter_secure_storage` |
| Localization | `flutter_localizations` + ARB files |
| Offline buffer | `sqflite` (speed logs only) |

---

## 📱 FLUTTER CONVENTIONS

### Always Use ApiConstants — Never Hardcode URLs

```dart
// ✅ CORRECT
final response = await _dio.post(ApiConstants.checkIn, data: body);

// ❌ WRONG
final response = await _dio.post('/attendance/check-in', data: body);
```

### Always Use Localization — Never Hardcode Strings

```dart
// ✅ CORRECT
Text(AppLocalizations.of(context).checkIn)

// ❌ WRONG
Text('Check In')
```

### Standard Repository Pattern

```dart
class AttendanceRepository {
  final ApiClient _client;
  AttendanceRepository(this._client);

  Future<CheckInResponse> checkIn(CheckInRequest request) async {
    final response = await _client.dio.post(
      ApiConstants.checkIn,
      data: request.toJson(),
    );
    return CheckInResponse.fromJson(response.data['data']);
  }
}
```

### Standard Riverpod Provider Pattern

```dart
final attendanceRepositoryProvider = Provider((ref) {
  return AttendanceRepository(ref.read(apiClientProvider));
});

final checkInProvider = StateNotifierProvider<CheckInNotifier, AsyncValue<CheckInResponse?>>((ref) {
  return CheckInNotifier(ref.read(attendanceRepositoryProvider));
});
```

### Error Handling — Always Map API Error Codes

```dart
try {
  final result = await repository.checkIn(request);
  // success
} on DioException catch (e) {
  final code = e.response?.data['error']['code'];
  switch (code) {
    case 'OUTSIDE_GEOFENCE':
      // show distance error with metres
    case 'GPS_ACCURACY_LOW':
      // ask user to move to open area
    case 'ALREADY_CHECKED_IN':
      // navigate to check-out
  }
}
```

### RTL Arabic Support

```dart
// Wrap entire app — already in main.dart
Directionality(
  textDirection: locale?.languageCode == 'ar'
      ? TextDirection.rtl
      : TextDirection.ltr,
  child: child,
)
```

### Pause Reason — MANDATORY (Cannot Be Skipped)

```dart
// PauseReasonBottomSheet must:
// 1. Use WillPopScope to prevent back-swipe dismiss
// 2. Keep confirm button disabled until reason is selected
// 3. Show text field when 'Other' is selected
// 4. Keep confirm disabled until text field is non-empty (for Other)
```

---

## 🔐 JWT Token Handling

- Stored in `flutter_secure_storage` — never in SharedPreferences
- `ApiClient` interceptor automatically attaches `Authorization: Bearer {token}`
- On 401 → auto-refresh via `POST /api/v1/auth/refresh`
- On refresh fail → clear tokens → navigate to LoginScreen
- FCM token registered via `PUT /api/v1/profile/fcm-token` immediately after login

---

## ⚡ PERFORMANCE RULES

- Use `const` constructors everywhere possible
- Paginate all lists — never load full datasets
- Cache profile + company info in Riverpod state — don't re-fetch on every navigation
- Speed logs buffered in local SQLite — batch upload every 5 readings, not every single one

---

## 📋 FEATURE IMPLEMENTATION ORDER (per screen)

1. Read `docs/API_CONTRACTS.md` for this screen's endpoint(s)
2. Create request/response model classes
3. Create repository method
4. Create Riverpod provider + notifier
5. Build screen UI with localized strings
6. Wire up provider → UI → error handling
7. Test: EN layout → AR layout (RTL) → HI layout
8. `flutter analyze` → zero errors
9. Update `TASKS.md` → `[✅] YYYY-MM-DD`

---

## 📌 QUICK REFERENCE

### Common Flutter Commands

```bash
flutter pub get                    # install packages
flutter gen-l10n                   # regenerate from ARB files (run after any ARB change)
flutter analyze                    # lint check — must be clean
flutter test                       # run tests
flutter run                        # run on connected device/emulator
flutter build apk --release        # build release APK
```

### Adding a New Localized String

1. Add to `lib/l10n/app_en.arb`
2. Add to `lib/l10n/app_ar.arb`
3. Add to `lib/l10n/app_hi.arb`
4. Run `flutter gen-l10n`
5. Use: `AppLocalizations.of(context).yourKey`

### Checking Which API Endpoint a Screen Needs

```bash
grep -A 5 "LoginScreen" docs/API_CONTRACTS.md
grep -A 5 "CheckInScreen" docs/API_CONTRACTS.md
grep -A 5 "PauseReasonBottomSheet" docs/API_CONTRACTS.md
```

---

*Last updated: March 2026 | Repo: City-Group-Flutter | API: https://api-city-group.codexkw.co/api/v1*
