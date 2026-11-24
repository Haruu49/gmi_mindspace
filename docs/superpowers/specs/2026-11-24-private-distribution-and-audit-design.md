# Private distribution (Android, iOS) and final audit (short design)

Date: 2026-11-24 · Status: **approved 2026-11-24**

## Intent
Get GMI MindSpace onto selected testers' phones without any app store, prove the
core flows work against the real dev database, and leave an honest audit with a
full document set.

## Goals / non-goals / anti-goals
- Goals: signed Android APK; iOS project configured for private testing; tested
  flows reported truthfully; README plus seven guides; outstanding-task list.
- Non-goals: Google Play or App Store submission; building iOS here (this
  machine is Linux, so no Xcode).
- Anti-goals: a signing key, keystore password or test password in git; any
  claim of a test or build that did not actually run.

## Approaches (chosen in bold)
- Icon/splash: **render the code-drawn `BrandLogo` to PNGs, generate all sizes
  with `flutter_launcher_icons` + `flutter_native_splash` (dev dependencies)**;
  rejected: hand-drawn Android vector (Android only).
- Test accounts: **SQL through the Supabase connection, pre-confirmed, roles set
  directly**; rejected: app sign-up (mail to fake addresses, rate limits).
- Signing: **dedicated release keystore outside the repo + git-ignored
  `android/key.properties`, universal APK**; rejected: split-per-ABI APKs.

## A. Android
- Package `my.edu.gmi.mindspace` (applicationId + namespace; move
  `MainActivity.kt`). Label "GMI MindSpace" (already set).
- Version `1.0.0+1` (bump the `+N` build number for every tester build).
- Permissions review: keep INTERNET, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED;
  add nothing unless code needs it (image_picker uses the system photo picker).
- Production config: release signed with the release key; built with
  `--dart-define-from-file=env/dev.json` (only one Supabase project exists, so
  "production" currently points at the dev project; documented as a known issue);
  R8 shrinking left on (Flutter default); cleartext traffic stays off.
- Keystore at `~/.gmi-mindspace-signing/` (outside repo), random passwords,
  `key.properties` git-ignored (already in `.gitignore`). Release build fails
  loudly if `key.properties` is missing rather than silently using the debug key.
- Install guide: enable "Install unknown apps", transfer APK, install, first-run.

## Testing (Android emulator `Medium_Phone`, live dev database)
- Fictional accounts in `gmi-mindspace-dev`: one student, one counsellor;
  passwords random, stored only in git-ignored `env/test_accounts.json`.
- New `integration_test/live_smoke_test.dart`, credentials via `--dart-define`:
  login, navigation across tabs, database read/write, the six student modules
  (mood check-in, journal, self-care, appointment request, learning hub,
  activities), session persistence (app restart stays signed in), offline and
  network-error messages (emulator network switched off with `adb`).
- Results reported exactly as they ran; anything not run is listed as not run.
- Physical-phone testing: not possible without a connected phone; documented
  as an outstanding task with a checklist.

## B. iOS (configured here, tested on a Mac by you)
- Bundle ID `my.edu.gmi.mindspace`, display name "GMI MindSpace", icons and
  launch screen from the same generators, Info.plist: auth deep-link URL scheme,
  photo-library usage text (content images), no unused permission strings.
- Supabase via the same `--dart-define-from-file`.
- Guide: Apple ID vs paid Developer Program, signing team, direct development
  install, Ad Hoc (device UDIDs, 100-device limit, yearly re-sign), TestFlight
  internal testing (recommended once there are more than a few testers).
  Simulator and iPhone tests marked **not run**.

## C. Audit and documents
- Review the 14 areas and the six features by reading code, running the test
  suites, and the Supabase security/performance advisors (read-only).
- Clear defects found (broken navigation, unimplemented buttons, exposed
  credentials, missing error handling or privacy notices) are fixed test-first;
  bigger items go to the known-issues report.
- Documents in `docs/`: INSTALLATION, DATABASE, USER_GUIDE, COUNSELLOR_GUIDE,
  TESTING_REPORT, DEPLOYMENT (Android + iOS), KNOWN_ISSUES; README refreshed;
  final outstanding-task list.

## Open for your approval
- Apply migration `015` (counsellor sign-up) to `gmi-mindspace-dev` so it can be
  tested too? Proposed: **yes**.
- Commit and push happen only when you say so.
