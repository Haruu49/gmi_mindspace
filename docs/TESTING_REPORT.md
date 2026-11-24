# GMI MindSpace – Testing report

Date: **2026-11-24** · Build: `1.0.0+1` · Package `my.edu.gmi.mindspace`

Only tests that actually ran are marked **Passed**. Everything else is marked **Not run**.
Fictional accounts only (`mindspace.student.a@example.test`, `mindspace.student.b@example.test`,
`mindspace.counsellor@example.test`); no real student data was used.

## 1. Summary

| Suite | Where | Result |
|---|---|---|
| Static analysis (`flutter analyze`) | Linux laptop | **Passed** – no issues |
| Unit tests (`flutter test test/unit`) | Linux laptop | **Passed** – 39 / 39 |
| Widget tests (`flutter test test/widget`) | Linux laptop | **Passed** – 74 / 74 |
| Database security, local (`supabase/tests/run_local.sh`) | PostgreSQL 16 on the laptop | **Passed** – 78 / 78 checks |
| Workflow tests, in-memory data (`integration_test/app_flow_test.dart`) | Android emulator | **Passed** – 3 / 3 |
| **Live smoke test** against the dev database (`integration_test/live_smoke_test.dart`) | Android emulator ↔ `gmi-mindspace-dev` | **Passed** – 1 / 1 (covers login, navigation, all six student modules, sign-out, counsellor login) |
| **Live security test** (`integration_test/supabase_security_test.dart`) | Android emulator ↔ `gmi-mindspace-dev` | **Passed** – 6 / 6 |
| Signed release APK: session persistence and offline behaviour (manual, adb) | Android emulator | **Passed** – see §4 |
| Physical Android phone | – | **Not run** (no phone connected) |
| iOS simulator / physical iPhone | – | **Not run** (needs macOS + Xcode) |
| TalkBack / VoiceOver walkthrough | – | **Not run** |

Test device: Android emulator `Medium_Phone`, Android 17 (API 37), 1080 × 2400, x86_64, connected to
the internet through the host.

## 2. Release APK checks

| Check | Result |
|---|---|
| `flutter build apk --release --dart-define-from-file=env/dev.json` | **Passed** – `app-release.apk`, 63.1 MB |
| `apksigner verify` | **Passed** – v2 signature, `CN=GMI MindSpace, OU=Counselling Unit, O=German-Malaysian Institute` (not the debug key) |
| Package / version / label (`aapt dump badging`) | `my.edu.gmi.mindspace`, versionCode 1, versionName 1.0.0, "GMI MindSpace", minSdk 24, targetSdk 36 |
| Permissions in the APK | INTERNET, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, VIBRATE (plus the AndroidX internal receiver permission) |
| Release build without `android/key.properties` | **Fails as intended** with "android/key.properties is missing…" |
| Keystore / passwords in git | **None** – `git status` and `git check-ignore` confirmed |

## 3. Live smoke test – what it covered (passed)

Real app, real Supabase dev project, student account A:

| Step | Verified |
|---|---|
| Login | Student sign-in reaches "Hello, Test!"; a Supabase session exists |
| Database connectivity | Rows written by the app were read back directly from the database |
| **Mood Check-in** | "Good" + note saved; exactly one matching `mood_entries` row with mood `good` |
| **My Journal** | Entry created; exactly one matching `journal_entries` row |
| **Self-care Corner** | Self-care tab, Breathe exercise start and stop |
| **Counselling Appointment** | Booking tab and *Request appointment* form load without errors (no appointment submitted; the test counsellor has no time slots) |
| **Learning Hub** | Topics load without errors |
| **Well-being Activities** | Activities screen loads without errors |
| Navigation | Home, Self-care, Booking, Profile tabs and back navigation |
| Clean-up | Test mood and journal rows deleted; verified empty |
| Sign-out | Returns to Student Login; session cleared |
| Counsellor login | Lands on the counsellor dashboard ("Pending requests"), no student screens |

Not covered live: submitting an appointment (needs counsellor availability), programme
registration and feedback, mood sharing, counsellor workflows beyond login, admin screens
(no admin account exists), counsellor self-sign-up email code (email template / SMTP not set up).
These flows are covered by widget tests with in-memory data and by the local database checks.

## 4. Release APK on the emulator (manual, adb)

Screenshots in [`docs/screenshots/`](screenshots/).

| # | Scenario | Expected | Result |
|---|---|---|---|
| 1 | Fresh install, open app | Welcome screen with Student / Counsellor Login, Get Help Now | **Passed** (`01_welcome.png`) |
| 2 | Student sign-in (live) | Dashboard; notification permission asked **after** sign-in | **Passed** (`02_signed_in.png`) |
| 3 | Force-stop, relaunch | Still signed in (session persisted) | **Passed** (`03_after_restart.png`) |
| 4 | Wi-Fi + mobile data off, relaunch | Friendly "No connection" screen with Try again and Sign out; no crash or endless spinner | **Passed** (`04_offline_launch.png`) |
| 5 | Network back on, Try again | Dashboard loads | **Passed** |
| 6 | Network off while signed in, open My Journal | Screen stays usable; list area shows "No connection" + Try again | **Passed** (`05_offline_in_session.png`) |
| 7 | Signed out, network off, sign in | "You seem to be offline…" message on the login form | **Passed** (`06_offline_login.png`) |

## 5. Manual device checklist

To be completed on each **physical** Android phone and on iOS (simulator + iPhone). Status for
all rows: **Not run**.

- [ ] Install (APK / TestFlight / Ad Hoc) and open; icon and splash look right
- [ ] Create a student account; confirmation email link opens the app
- [ ] Student sign-in; notification prompt after sign-in
- [ ] Mood check-in saved and visible in history and charts
- [ ] Journal: create, edit, search, delete
- [ ] Self-care: breathing, grounding, gratitude
- [ ] Request an appointment (counsellor must first add availability); cancel it
- [ ] Learning Hub: open an article, bookmark, recently viewed
- [ ] Activities: register, cancel, feedback after start
- [ ] Get Help Now: each phone number opens the dialler
- [ ] Close and reopen: still signed in
- [ ] Aeroplane mode: friendly offline messages; recovers with Try again
- [ ] Counsellor: confirm / reject / reschedule / notes / availability / programme / content
- [ ] Counsellor self-sign-up with a real `@gmi.edu.my` mailbox and the emailed code
- [ ] Reminder notification arrives (appointment 24 h / 1 h)
- [ ] Dark mode and large text
- [ ] TalkBack (Android) / VoiceOver (iOS): every control announced with a clear label

## 6. How to re-run

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
flutter analyze && flutter test && bash supabase/tests/run_local.sh
flutter test integration_test/app_flow_test.dart -d <device>
flutter test integration_test/live_smoke_test.dart -d <device> \
  --dart-define-from-file=env/dev.json --dart-define-from-file=env/test_accounts.json
flutter test integration_test/supabase_security_test.dart -d <device> \
  --dart-define-from-file=env/dev.json --dart-define-from-file=env/test_accounts.json
```
