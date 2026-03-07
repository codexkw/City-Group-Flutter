# TASKS.md — City Group Flutter App
> Last updated: March 2026
> Claude Code: Run `cat TASKS.md` and `cat docs/API_CONTRACTS.md` at the start of every session.

---

## Status Legend
```
[ ]  — Not started
[⏳] — In progress
[✅] — Completed (YYYY-MM-DD)
[❌] — Blocked (reason)
[⏸️] — Paused
```

---

## Progress Overview

| Phase | Total | Done | Remaining |
|-------|-------|------|-----------|
| Phase 1: Project Setup | 10 | 10 | 0 |
| Phase 2: Core Infrastructure | 8 | 4 | 4 |
| Phase 3: Auth Screens | 6 | 4 | 2 |
| Phase 4: Home + Attendance | 6 | 6 | 0 |
| Phase 5: Tasks | 7 | 7 | 0 |
| Phase 6: Notifications + Profile | 6 | 5 | 1 |
| Phase 7: Speed Monitoring | 4 | 0 | 4 |
| Phase 8: Polish + QA | 5 | 0 | 5 |
| **Total** | **52** | **36** | **16** |

---

## Phase 1: Project Setup

- [✅] 2026-03-07 Run `flutter create` and set up project
- [✅] 2026-03-07 Replace `pubspec.yaml` with all packages
- [✅] 2026-03-07 Replace `lib/main.dart` with provided version
- [✅] 2026-03-07 Copy `l10n.yaml` to repo root
- [✅] 2026-03-07 Copy ARB files (app_en.arb, app_ar.arb, app_hi.arb)
- [✅] 2026-03-07 Copy `api_constants.dart`
- [✅] 2026-03-07 Copy `api_client.dart`
- [✅] 2026-03-07 Run `flutter pub get` — no errors
- [✅] 2026-03-07 Run `flutter gen-l10n` — generates app_localizations.dart
- [✅] 2026-03-07 Download and add fonts (NotoSansArabic, NotoSansDevanagari)

---

## Phase 2: Core Infrastructure

- [✅] 2026-03-07 `lib/core/theme/app_theme.dart` — Material 3 theme with City Group colors
- [✅] 2026-03-07 `lib/core/router/app_router.dart` — GoRouter with 12 routes + auth guard
- [✅] 2026-03-07 `lib/features/auth/presentation/providers/auth_provider.dart` — authState + locale
- [✅] 2026-03-07 `lib/core/api/api_client.dart` — verified JWT interceptor
- [ ] Request/Response model base classes (ApiResponse<T>, ApiError)
- [ ] Shared widgets (LoadingButton, ErrorSnackBar, EmptyState, AppBottomNavBar)
- [ ] `flutter analyze` — clean
- [ ] `flutter test` — pass

---

## Phase 3: Auth Screens

- [✅] 2026-03-07 `auth_repository.dart` — login, logout, forgotPassword, resetPassword
- [✅] 2026-03-07 `login_screen.dart` — full implementation with error handling
- [✅] 2026-03-07 `forgot_password_screen.dart` — 2-step flow (phone → OTP + new password)
- [ ] `biometric_screen.dart` — local_auth fingerprint/FaceID
- [ ] After login: register FCM token
- [✅] 2026-03-07 `flutter analyze` + `flutter test` — pass

---

## Phase 4: Home + Attendance

- [✅] 2026-03-07 `attendance_repository.dart` — checkIn, checkOut, getToday, getHistory, getLocations
- [✅] 2026-03-07 `home_screen.dart` — welcome card, quick actions, bottom nav
- [✅] 2026-03-07 `check_in_screen.dart` — GPS + location selection + geofence error handling
- [✅] 2026-03-07 `check_out_screen.dart` — GPS + total hours on success
- [✅] 2026-03-07 `attendance_history_screen.dart` — paginated list + status badges
- [✅] 2026-03-07 `flutter analyze` + `flutter test` — pass

---

## Phase 5: Tasks

- [✅] 2026-03-07 `task_repository.dart` — getToday, getById, start, pause, resume, complete
- [✅] 2026-03-08 `task_list_screen.dart` — sorted by status+priority, badges, navigation
- [✅] 2026-03-08 `task_detail_screen.dart` — live elapsed timer, start/pause/resume/complete buttons
- [✅] 2026-03-08 `pause_reason_bottom_sheet.dart` — mandatory reason, PopScope, Other text field
- [✅] 2026-03-08 `task_complete_modal.dart` — notes + photo capture (camera)
- [✅] 2026-03-08 `task_provider.dart` — taskRepository, todayTasks, taskDetail providers
- [✅] 2026-03-08 `flutter analyze` + `flutter test` — pass

---

## Phase 6: Notifications + Profile

- [ ] Firebase Messaging setup (google-services.json, foreground/background handling)
- [✅] 2026-03-07 `notifications_repository.dart` — getAll, markAsRead, markAllAsRead
- [✅] 2026-03-08 `notifications_screen.dart` — unread highlight, mark read, deep-link to tasks
- [✅] 2026-03-07 `profile_repository.dart` — getProfile, updateProfile, updateLanguage, changePassword
- [✅] 2026-03-07 `profile_screen.dart` + `language_settings_screen.dart` — working language switch
- [✅] 2026-03-08 `change_password_screen.dart` — form with validation, error handling

---

## Phase 7: Speed Monitoring (Background Service)

- [ ] Local SQLite buffer setup (speed_readings table)
- [ ] `background_speed_service.dart` — flutter_background_service + GPS speed tracking
- [ ] Speed alert UI (persistent top banner on violation)
- [ ] Company speed settings stored locally

---

## Phase 8: Polish + QA

- [ ] Full RTL audit (Arabic)
- [ ] Full Hindi audit (Devanagari rendering)
- [ ] Zero hardcoded strings audit
- [ ] `flutter analyze` — zero errors/warnings + `flutter test` — all pass
- [ ] `flutter build apk --release` — compiles + GitHub Actions CI

---

## Bug Tracker

| ID | Screen | Description | Status |
|----|--------|-------------|--------|
| 1 | api_client.dart | `prefer_const_constructors` info warnings | Low priority |
| 2 | check_in/out | `use_build_context_synchronously` info warnings | Low priority |

---

## Key Decisions

| Decision | Reason |
|----------|--------|
| Riverpod for state (not Bloc/Provider) | Consistent with pubspec.yaml setup |
| Pause reason cannot be dismissed | PRD requirement — mandatory server-side too |
| Speed logs buffered in SQLite | Offline-first — network not always available in field |
| JWT in flutter_secure_storage | More secure than SharedPreferences |
| RTL via Directionality widget in main.dart | Single control point for entire app |
| geolocator 11.x uses `desiredAccuracy` param | Not `locationSettings` — API changed in v11 |

---

*Last updated: 2026-03-08 | Done: 36/52 (69%) | Remaining: Phase 2 (shared widgets), Phase 3 (biometric, FCM), Phase 7 (speed monitoring), Phase 8 (polish)*
