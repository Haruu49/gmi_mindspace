# Private Distribution and Final Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Signed Android APK and configured iOS project for private testing, live-tested core flows, and an honest audit with a full document set.

**Architecture:** Config changes in `android/` and `ios/`, brand assets rendered from the code-drawn `BrandLogo`, one live integration test run on the Android emulator against `gmi-mindspace-dev` (ref `ggxjsrnhzlpeqpwecqzr`), documents in `docs/`.

**Tech Stack:** Flutter 3 / Dart, Gradle Kotlin DSL, Supabase (MCP for migration + test accounts), flutter_launcher_icons, flutter_native_splash, Android emulator `Medium_Phone`.

**Spec:** `docs/superpowers/specs/2026-11-24-private-distribution-and-audit-design.md`

## Global Constraints

- Package / bundle ID: `my.edu.gmi.mindspace`; name "GMI MindSpace"; version `1.0.0+1`.
- Never commit: keystore, `android/key.properties`, `env/dev.json`, `env/test_accounts.json`, any password.
- Keystore lives in `~/.gmi-mindspace-signing/` (outside the repo).
- Test accounts are fictional, `@example.test`, random passwords, stored only in `env/test_accounts.json`.
- No store submission. No commit/push until the user asks.
- Report only what actually ran; anything not run is written as **not run**.
- Flutter: `~/development/flutter/bin/flutter`; JDK: `/snap/android-studio/current/jbr`.

## Review Focus

- Release build when `android/key.properties` is missing must fail, not fall back to the debug key.
- Deep link `my.edu.gmi.mindspace://auth-callback` still opens the app after the package rename.
- App launched with no network shows the friendly offline message, not a crash or spinner forever.
- Signed-in session survives an app restart; a signed-out user returns to Welcome.
- No secret appears in `git status` / staged files after the build.

---

### Task 1: Database — apply migration 015 and create test accounts
- [ ] Apply `supabase/migrations/20261124000015_counsellor_signup.sql` via MCP `apply_migration` (name `counsellor_signup`). Verify: `list_migrations` shows it; `select tgname from pg_trigger where tgname = 'on_auth_user_email_confirmed'` returns one row.
- [ ] Generate three random passwords locally; write `env/test_accounts.json` with `TEST_STUDENT_A`, `TEST_STUDENT_B`, `TEST_COUNSELLOR`, `TEST_PASSWORD`. Confirm `git check-ignore env/test_accounts.json` matches.
- [ ] Insert the three confirmed users (`auth.users` + `auth.identities`, bcrypt password) via `execute_sql`; set the counsellor's role to `counsellor`. Verify with a query of `user_roles` joined to emails: 2 students, 1 counsellor.

### Task 2: Android identity, signing and production config
**Files:** `android/app/build.gradle.kts`, `android/app/src/main/kotlin/my/edu/gmi/mindspace/MainActivity.kt` (moved), `android/key.properties` (local only)
- [ ] `namespace` and `applicationId` → `my.edu.gmi.mindspace`; move `MainActivity.kt` and change its `package` line.
- [ ] `signingConfigs.release` reads `android/key.properties` (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`); `release` build type uses it; if the file is missing, a release task throws `GradleException("android/key.properties is missing …")`. Debug builds unaffected.
- [ ] Create keystore with `keytool -genkeypair` (RSA 4096, validity 10000 days, alias `gmi-mindspace`) in `~/.gmi-mindspace-signing/`, random passwords; write `android/key.properties`; `chmod 600` both. Verify `git check-ignore android/key.properties`.
- [ ] Permissions: unchanged (INTERNET, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED); document why each exists.

### Task 3: Icon and splash (Android + iOS)
**Files:** `tool/render_brand_assets_test.dart`, `assets/branding/*.png`, `pubspec.yaml`
- [ ] Render `BrandLogo` (light) to `assets/branding/icon.png` (1024², full square background), `icon_foreground.png` (1024², logo at 66 % on transparent, for Android adaptive icons) and `splash.png` (512², transparent) with a test that paints via `RepaintBoundary.toImage`. Verify files exist and are the right size.
- [ ] Add dev deps `flutter_launcher_icons`, `flutter_native_splash`; configure (Android adaptive background = brand lavender, iOS `remove_alpha_ios: true`; splash colour = app light background, dark variant = dark background); run both generators. Verify mipmaps and `AppIcon.appiconset` replaced, `LaunchImage` present.

### Task 4: iOS configuration
**Files:** `ios/Runner.xcodeproj/project.pbxproj`, `ios/Runner/Info.plist`
- [ ] `PRODUCT_BUNDLE_IDENTIFIER` → `my.edu.gmi.mindspace` (RunnerTests → `my.edu.gmi.mindspace.RunnerTests`); `CFBundleName` → `GMI MindSpace`.
- [ ] Remove `NSCameraUsageDescription` (code only picks from the gallery: `content_editor_screen.dart:68`); keep photo-library text, URL scheme, query schemes.

### Task 5: Build and verify the signed APK
- [ ] `flutter analyze` and `flutter test` green.
- [ ] `flutter build apk --release --dart-define-from-file=env/dev.json`. Expected: `build/app/outputs/flutter-apk/app-release.apk`.
- [ ] `apksigner verify --print-certs` shows the `gmi-mindspace` certificate (not "Android Debug"); `aapt dump badging` shows `package: name='my.edu.gmi.mindspace' versionCode='1' versionName='1.0.0'` and label "GMI MindSpace".
- [ ] Temporarily rename `key.properties` and confirm the release build fails with the message; restore.

### Task 6: Live testing on the emulator
**Files:** `integration_test/live_smoke_test.dart`
- [ ] Write the test (real `main()` app, credentials from `--dart-define-from-file=env/test_accounts.json`, skip when absent): student login → dashboard; each tab; mood check-in saved and shown in history; journal entry create + delete; self-care breathing opens; appointment booking screen loads counsellors; learning hub lists resources; activities list loads; sign out. Counsellor login → counsellor dashboard.
- [ ] Run on `Medium_Phone` and record results. Run the existing `supabase_security_test.dart` too.
- [ ] Session persistence: install release APK with `adb`, sign in, force-stop, relaunch; screenshot shows dashboard.
- [ ] Offline: `adb shell svc wifi disable; svc data disable`, relaunch / pull-to-refresh; screenshot of the message; re-enable.
- [ ] Fix any defect found, test-first.

### Task 7: Audit and documents
- [ ] Review the 14 areas and six features (code reading, grep for TODO/placeholder/dummy data/`onPressed: () {}`, credentials scan, Supabase advisors). Fix clear defects test-first.
- [ ] Write `docs/INSTALLATION.md`, `docs/DATABASE.md`, `docs/USER_GUIDE.md`, `docs/COUNSELLOR_GUIDE.md`, `docs/TESTING_REPORT.md`, `docs/DEPLOYMENT.md` (Android sideload + iOS signing/Ad Hoc/TestFlight), `docs/KNOWN_ISSUES.md`; refresh `README.md` links and counts.
- [ ] Final `flutter analyze`, `flutter test`, `bash supabase/tests/run_local.sh`; `git status` shows no secret files.
