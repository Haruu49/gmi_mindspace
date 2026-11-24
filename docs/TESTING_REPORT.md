# GMI MindSpace – Testing report

Date: **2026-11-24** · Build: `1.0.0+1` · Package `my.edu.gmi.mindspace`

Only tests that actually ran are marked **Passed**. Everything else is marked **Not run**.
Fictional accounts only (`mindspace.student.a@example.test`, `mindspace.student.b@example.test`,
`mindspace.counsellor@example.test`); no real student data was used.

## 1. Summary

| Suite | Where | Result |
|---|---|---|
| Static analysis (`flutter analyze`) | Linux laptop | **Passed** – no issues |
| Unit tests (`flutter test test/unit`) | Linux laptop | **Passed** – 46 / 46 |
| Widget tests (`flutter test test/widget`) | Linux laptop | **Passed** – 84 / 84 |
| Database security, local (`supabase/tests/run_local.sh`) | PostgreSQL 16 on the laptop | **Passed** – 90 / 90 checks |
| Workflow tests, in-memory data (`integration_test/app_flow_test.dart`) | Android emulator | **Passed** – 3 / 3 |
| **Live smoke test** against the dev database (`integration_test/live_smoke_test.dart`) | Android emulator ↔ `gmi-mindspace-dev` | **Passed** – 1 / 1 (covers login, navigation, all six student modules, sign-out, counsellor login) |
| **Live security test** (`integration_test/supabase_security_test.dart`) | Android emulator ↔ `gmi-mindspace-dev` | **Passed** – 6 / 6 |
| Signed release APK: session persistence and offline behaviour (manual, adb) | Android emulator | **Passed** – see §4 |
| **Learning Hub PDFs**, live storage checks (scratchpad script, REST API) | `gmi-mindspace-dev` | **Passed** – 12 / 12, see §4b |
| Learning Hub PDFs in the release APK (manual, adb) | Android emulator | **Passed** – see §4b |
| Physical Android phone | OPPO CPH2739, Android 16 (ColorOS), mobile data | **Partly run** – release APK installs and updates in place; student sign-in; Learning Hub **Open PDF**; counsellor **Attach PDF** via the phone's file picker, save, delete (see §4c). Full checklist §5 not done |
| iOS build (`.github/workflows/ios-build.yml`) | GitHub Actions macOS runner, Xcode 26.6 | **Passed** – release build without code signing, `Runner.app` 22.4 MB, unsigned `.ipa` 8.8 MB attached to `v1.0.0-test.1` (run 45362393932) |
| iOS simulator / physical iPhone | – | **Not run** (needs macOS + Xcode, or a sideloaded build on an iPhone) |
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

## 4b. Learning Hub PDF materials (2026-11-24)

Live storage checks against `gmi-mindspace-dev` with the fictional accounts (all **passed**):
counsellor uploads a PDF · counsellor publishes a *Download* resource with the PDF and no link ·
student gets a signed link · the link downloads the real PDF (`%PDF-` bytes) · no public link
exists · student cannot upload · bucket refuses a non-PDF content type · bucket refuses a PDF over
20 MB · counsellor unpublishes · student can no longer get a link · resource and file deleted.

Release APK on the emulator (all **passed**; screenshots `07`–`10`):

| Step | Result |
|---|---|
| Student: Learning Hub card shows a **PDF** label | Passed (`07_pdf_card.png`) |
| Student: **Open PDF** opens the file in the phone's PDF viewer (Chrome) | Passed (`08_pdf_opened.png`) |
| Counsellor: **Attach PDF** opens the system picker, filtered to PDFs | Passed (`09_pdf_picker.png`) |
| Counsellor: picked file uploads; editor shows name and size | Passed (`10_pdf_attached.png`) |
| Counsellor: Save stores path, name and size; file present in storage | Passed (checked in the database) |
| Counsellor: deleting the resource also deletes its file from storage | Passed (checked in the database) |

All test resources and files were removed afterwards (0 left in the bucket).

## 4c. Physical phone: OPPO CPH2739, Android 16 (2026-11-24)

Release APK installed over USB (`adb install -r`, update kept the app data). Fictional accounts
only; the owner's own account was not used.

| Step | Result |
|---|---|
| Student signs in over mobile data | Passed |
| Learning Hub ▸ Stress Management shows the PDF resource with its PDF label | Passed |
| **Open PDF** opens the file in Chrome's PDF viewer, which offers "download" | Passed |
| Counsellor: **Attach PDF** opens the system file picker filtered to PDFs | Passed |
| Picked file uploads; editor shows "MindSpace test worksheet.pdf · 1 KB" | Passed |
| Save stores path, name and size; file present in storage | Passed (checked in the database) |
| Deleting the resource removes the file from storage | Passed (checked in the database) |
| Sign-out of both accounts | Passed |

All temporary resources, files (including the test PDF copied to the phone) were removed.

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
- [ ] Learning Hub: open an article, bookmark, recently viewed, **Open PDF**
- [ ] Counsellor: attach a PDF from the phone's files, publish, open it as a student
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
