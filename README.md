# GMI MindSpace

**Your Space. Your Pace. Your Well-being.**

A student-friendly mental health and well-being app for the German-Malaysian Institute (GMI),
built with Flutter (Android + iOS), Riverpod, GoRouter and Supabase (PostgreSQL + Row Level Security).

> **Status: private-testing build – not production-ready.** A signed Android APK exists for
> selected testers; iOS is configured but not yet built. See [Readiness](#readiness) and
> [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) for exactly what has and has not been verified.

## Download (Android test build)

**[Latest test build on GitHub Releases](https://github.com/Haruu49/gmi_mindspace/releases)** – a
signed APK for Android 7.0+. It is a **testing build**: it connects to the development database,
so use fictional details only, and do not rely on it for support or emergencies. Install steps:
[docs/INSTALLATION.md](docs/INSTALLATION.md#installing-the-android-apk). Not on Google Play; no
iOS build yet.

## Documentation

| Document | For |
|---|---|
| [Installation guide](docs/INSTALLATION.md) | Testers installing the APK; developers setting up the project |
| [User guide](docs/USER_GUIDE.md) | Students |
| [Counsellor guide](docs/COUNSELLOR_GUIDE.md) | Counsellors and administrators |
| [Database documentation](docs/DATABASE.md) | Schema, RLS, functions, triggers |
| [Deployment guide](docs/DEPLOYMENT.md) | Signed Android APK, iOS (Mac, signing, Ad Hoc, TestFlight), Supabase checklist |
| [Testing report](docs/TESTING_REPORT.md) | What was tested, how, and the results |
| [Known issues](docs/KNOWN_ISSUES.md) | Open problems and outstanding tasks |

---

## Contents

1. [What the app does](#what-the-app-does)
2. [Architecture](#architecture)
3. [Folder structure](#folder-structure)
4. [Getting started (step by step)](#getting-started-step-by-step)
5. [Supabase setup](#supabase-setup)
6. [Security and privacy model](#security-and-privacy-model)
7. [Notifications](#notifications)
8. [Testing](#testing)
9. [Readiness](#readiness)

---

## What the app does

| Role | Modules |
|---|---|
| **Student** | Dashboard · Mood Check-in (history, weekly/monthly charts, reflection prompts, optional summary sharing) · My Journal (CRUD, prompts, gratitude, search) · Self-care Corner (breathing animation, 5-4-3-2-1 grounding, gratitude, 7 categories) · Counselling appointments (request, status, cancel, reschedule) · Learning Hub (browse, search, bookmarks, recently viewed) · Well-being Activities (calendar, register, cancel, feedback) · Profile · Notifications · Get Help Now |
| **Counsellor** | Self sign-up with Staff ID and an emailed 6-digit code · Dashboard overview · Appointment management (search, filters, confirm / reject with explanation / reschedule / complete, private notes) · Availability · Programme management (create, publish, registrations, attendance, feedback) · Learning Hub content management (cover images and **PDF materials for all students**) · Feedback & Reports (aggregated only) |
| **Administrator** | System health · User accounts (assign roles, activate/deactivate, content permission) · Audit log · App settings |

Built-in safeguards: no diagnosis or risk scoring anywhere, an always-reachable **Get Help Now** screen
(also before sign-in), and a clear notice that the app is **not monitored 24/7**.

---

## Architecture

Clean, feature-based architecture. Each feature has the same three layers:

```
presentation/  Screens + widgets. Read state from Riverpod providers. No SQL, no Supabase calls.
domain/        Plain Dart models, enums and pure logic (e.g. MoodStats). No Flutter/Supabase imports.
data/          Repositories: the only code that talks to Supabase. Return domain models,
               throw AppFailure (friendly message) instead of raw database errors.
```

```
 Screen ──watch──▶ FutureProvider / Notifier ──▶ Repository ──▶ Supabase (HTTPS + RLS)
   ▲                                                  │
   └──────────── AsyncValue (loading / error / data) ◀┘
```

Key decisions:

| Concern | Choice |
|---|---|
| State management | **Riverpod 3** (`FutureProvider` for reads, invalidation after writes, `Notifier` for auth). Automatic retry is disabled so errors show immediately with a *Try again* button. |
| Navigation | **GoRouter 18** with `StatefulShellRoute` tabs (students: Home / Mood / Self-care / Booking / Profile; counsellors: Overview / Appointments / Programmes / Content). A pure, unit-tested `redirectFor()` sends each role to its own area. Links between tabs use `go`; links within a tab use `push`. |
| Authorisation | The **database** decides. The role comes from `user_roles` (never from user-editable metadata). UI routing is only a convenience. |
| Writes with rules | Appointment and registration changes go through SQL workflow functions that validate ownership, assignment and status transitions. |
| Errors | `AppFailure.from()` maps network, auth, RLS, conflict (double booking) and session-expiry errors to friendly messages. Shared `LoadingView` / `EmptyView` / `ErrorView` / `AsyncValueView` widgets keep states consistent. |
| Design system | Material 3, `AppColors`, `AppTypography` (bundled **Nunito**, no runtime font downloads), `AppSpacing`, `AppRadius`, `LightTheme`, `DarkTheme`, reusable `AppButton`, `AppTextField`, `AppCard`, `FeatureCard`, `StatusChip`, dialogs and a custom-drawn logo and illustration. |
| Responsiveness | Content width is capped on tablets, grids adapt to screen width, and the bottom bar becomes a navigation rail at ≥ 840 px. Tested from 320 px phones to tablets and landscape. |
| Material package | This Flutter version (3.50) moved Material to `package:material_ui`. The app imports it everywhere (go_router does too). `table_calendar` was **not** used because it relies on the old Material package; a small `MonthCalendar` widget replaces it. |

### Colour palette

Lavender `#9274B8` (primary) · Sage `#A7B99A` (secondary) · Warm white `#FAF9F6` (background) ·
White surface · Navy `#263247` (text) · `#7B8290` (secondary text) · Success `#65A887` ·
Warning `#E8B66D` · Error `#D97979`.

---

## Folder structure

```
lib/
  main.dart                 Start-up: Supabase init (if configured), local notifications, ProviderScope
  app.dart                  MaterialApp.router, themes, notification sync
  core/
    constants/              Env (dart-define), app copy, emergency contacts
    theme/                  AppColors, AppTypography, AppSpacing, AppRadius, Light/DarkTheme, AppTheme
    routing/                AppRoutes, router, role guard, responsive shell
    services/               Supabase client, local notifications
    utils/                  Validators, AppFailure/guard, date helpers
    widgets/                Design-system widgets (buttons, fields, cards, states, dialogs, brand)
  features/
    authentication/         Splash, welcome, login (student + counsellor), register, password reset, privacy
    student_dashboard/      Dashboard, profile, edit profile
    mood_checkin/           Selection, reflection, history, analytics, consent-based sharing
    journal/                List/search, editor, detail
    selfcare/               Home, activity detail, breathing, grounding, gratitude, completion
    counselling/            Student booking flow + shared appointment data layer
    learning_hub/           Browse, detail, bookmarks + shared resource data layer
    wellbeing_activities/   Activities, calendar, registration, feedback + shared programme data layer
    counsellor_dashboard/   Overview, appointments, availability, programmes, content, reports
    administration/         Admin dashboard, users, audit log, settings
    notifications/          In-app list, preferences, realtime sync, FCM integration point
  shared/
    models/                 UserProfile, AppRole
    widgets/                Get Help Now, month calendar, avatar, setup screen
supabase/
  migrations/               16 ordered SQL migrations (schema, RLS, functions, grants)
  seed/seed.sql             Sample learning content + draft programmes (no users, no student data)
  functions/send-push/      Prepared FCM Edge Function (not deployed)
  tests/                    Local RLS test suite (67 checks) + runner
test/                       Unit + widget tests (98)
integration_test/           Device workflows + live Supabase security checks
env/dev.example.json        Template for credentials (real file is git-ignored)
```

---

## Getting started (step by step)

All steps are on **this laptop** unless stated.

**A. Run the tests (no Supabase needed)**

1. Open a terminal.
2. Run `export PATH="$HOME/development/flutter/bin:$PATH"`
3. Run `cd ~/Projects/gmi_mindspace`
4. Run `flutter pub get`
5. Run `flutter analyze` – it should say **No issues found**.
6. Run `flutter test` – it should end with **All tests passed**.
7. Run `bash supabase/tests/run_local.sh` – it should end with **ALL RLS TESTS PASSED (67 checks)**.

**B. Run the app on the Android emulator or a phone**

1. Finish [Supabase setup](#supabase-setup) first.
2. Run `cp env/dev.example.json env/dev.json`
3. Open `env/dev.json` and paste your project URL and **publishable** key.
4. Start the emulator from Android Studio (Device Manager ▸ ▶), or plug in your phone with USB debugging on.
5. Run `flutter devices` and note the device id.
6. Run `flutter run -d <device-id> --dart-define-from-file=env/dev.json`

Without `env/dev.json` the app still starts and shows a *Setup needed* screen, with Get Help Now still available.

> Optional: `flutter doctor` reports that Android **cmdline-tools** are missing. Install them in
> Android Studio ▸ SDK Manager ▸ SDK Tools ▸ *Android SDK Command-line Tools*, then run
> `flutter doctor --android-licenses`.

**iOS** builds need a Mac with Xcode; see [docs/DEPLOYMENT.md › iOS](docs/DEPLOYMENT.md#3-ios).
**Signed Android APK for testers:** see [docs/DEPLOYMENT.md › Android](docs/DEPLOYMENT.md#2-android).

---

## Supabase setup

**Development project (already set up, 2026-11-23):** `gmi-mindspace-dev`
(ref `ggxjsrnhzlpeqpwecqzr`, region Singapore, free plan). All 16 migrations and the seed are
applied (`015` and `016` on 2026-11-24). Three fictional test accounts exist (two students, one counsellor; credentials in the git-ignored `env/test_accounts.json`); `env/dev.json` on this laptop points to it. Verified live: 19 tables with RLS, 66 policies,
reminder cron job scheduled, realtime on `notifications`, and every table / admin function returns
**401 permission denied** to signed-out requests. Supabase's security advisor lists 20
"SECURITY DEFINER function executable by authenticated" warnings – these are the intended app
functions (booking, admin, reports); each checks the caller's role/ownership inside and is not
callable by `anon`.

Steps below are for setting up **another** project (e.g. production).

1. Create a project at supabase.com (use a **development** project first).
2. Apply the migrations **in filename order**:
   - with the Supabase CLI: `supabase link --project-ref <ref>` then `supabase db push`, **or**
   - paste each file from `supabase/migrations/` into the SQL editor, in order.
3. (Optional) Run `supabase/seed/seed.sql` in the SQL editor for sample content.
4. **Authentication ▸ URL configuration:** add `my.edu.gmi.mindspace://auth-callback` to the redirect URLs.
5. **Authentication ▸ Providers ▸ Email:** keep *Confirm email* on.
6. **Database ▸ Extensions:** enable `pg_cron`, then re-run migration `008` (or run the `cron.schedule` line from it) for reminders.
7. Create the first administrator: sign up in the app with a staff e-mail, then in the SQL editor run
   `update public.user_roles set role = 'admin' where user_id = (select id from auth.users where email = '<that e-mail>');`
8. **Counsellor sign-up (migration `015`):** counsellors sign up themselves in the app (**Counsellor Login ▸ Sign up**) with full name, Staff ID, a `@gmi.edu.my` email and a password. They receive a 6-digit code by email and become counsellors as soon as they enter it. For this to work:
   - **Authentication ▸ Email templates ▸ Confirm signup:** include `{{ .Token }}` (the 6-digit code) in the message, and keep `{{ .ConfirmationURL }}` so students still get their link.
   - **Authentication ▸ SMTP:** configure your own SMTP provider. Supabase's built-in sender is heavily rate-limited and not meant for real users.
   - Keep *Confirm email* on (step 5). With it off, no code is sent and counsellor sign-up refuses to continue.
   - Accepted risk: anyone who owns a `@gmi.edu.my` mailbox (for example a lecturer) can self-register as a counsellor. Every promotion is written to the audit log, and administrators can still demote or deactivate accounts in **Admin ▸ User accounts**.

Never put the service-role / secret key in the app or in `env/dev.json`. The app only uses the
publishable key. That is safe **because** every table is protected by RLS and explicit grants.

---

## Security and privacy model

Security is enforced in PostgreSQL, not just in the app. Every table in `public` has RLS enabled.
Since Supabase no longer exposes new tables automatically, migration `010` starts from **zero
privileges** and grants only what is needed. Column-level grants stop users writing protected columns
such as `user_id`, `status` or `is_active`. Signed-out (`anon`) users get no table access at all.

Helper functions (`private.is_student()`, `is_counsellor()`, `is_admin()`, …) live in an
**unexposed `private` schema**. They only describe the caller (`auth.uid()`), and a deactivated
account has no effective role, so every policy denies it immediately.

### Policies, table by table

| Table | Who can do what | Why |
|---|---|---|
| `profiles` | Read own · read counsellor names (for booking) · counsellors read students they have an appointment or programme registration with · admins read all · update own name / student ID / programme only | Basic account info only, with no mood or journal data. Users cannot activate themselves. |
| `user_roles` | Read own · admins read all · **no client writes** | Roles change only through `admin_set_user_role()`, which refuses self-changes, keeps at least one admin, and writes the audit log. New sign-ups are students; a `role` in sign-up metadata is ignored. The only other path is a **verified** `@gmi.edu.my` counsellor sign-up (trigger on `email_confirmed_at`, exact domain, valid and unused Staff ID, audited). |
| `mood_entries` | **Owner only**, all operations | No counsellor or admin policy exists. |
| `journal_entries` | **Owner only**, all operations | Counsellors and administrators cannot read journals through any API path. |
| `mood_share_consents` | Student creates / revokes own consent for one named counsellor · that counsellor sees the consent | The counsellor calls `get_shared_mood_summary()`, which returns **counts per mood only** while consent is active, never notes or reasons. Consent expires after 30 days. |
| `counsellor_availability` | Counsellors manage their own slots | An exclusion constraint blocks overlapping slots. |
| `appointments` | Student reads own · assigned counsellor reads · **no direct writes** | Workflow functions (`request_appointment`, `cancel_my_appointment`, `request_reschedule`, `counsellor_set_appointment_status`, `counsellor_reschedule_appointment`) check ownership, assignment and allowed transitions. **Double booking is impossible**: a `btree_gist` exclusion constraint rejects overlapping live appointments for a counsellor (and for a student), even under concurrent requests. Rejections require an explanation. |
| `appointment_list` (view) | Same as appointments (`security_invoker`) | Lists exclude the student's note and counsellor notes. |
| `appointment_notes` | Assigned counsellor (author) only | Never visible to students or admins. |
| `resources` | Active users read published · content managers (counsellors with permission, or admins) manage | Admins can revoke a counsellor's content permission. |
| `resource_bookmarks`, `resource_views` | Owner only | |
| `programmes` | Active users read non-drafts · counsellors manage (delete drafts only) | |
| `programme_registrations` | Student reads own · counsellors read all · writes only through `register_for_programme` / `cancel_programme_registration` / `mark_attendance` | A unique constraint prevents duplicates; the programme row is locked to prevent overfilling. |
| `feedback` | Student submits once, only if registered and the programme has started · reads own | Counsellors read through `get_programme_feedback()`, which hides names of anonymous feedback. |
| `notifications` | Owner reads / marks read / deletes · created only by server triggers | Generic text only. |
| `notification_preferences`, `device_tokens` | Owner only | |
| `audit_logs` | Admins read · **nobody can insert, edit or delete** from the client | Written only by admin functions. |
| `app_settings` | Active users read · admins update through audited function | |
| Storage `learning-media` | Public read · upload / replace / delete for content managers only · images ≤ 5 MB | |

**Reports** (`counsellor_dashboard_stats`, `programme_participation`) return aggregated counts only.
Groups smaller than 5 students are suppressed. There are no diagnostic, predictive or risk dashboards.

### Encryption review

- In transit: all traffic is HTTPS/TLS (Android cleartext traffic is disabled).
- At rest: Supabase encrypts database storage at rest (AES-256). Journals are additionally protected by owner-only RLS.
- Not implemented: end-to-end / column encryption of journal text. It would stop server-side search and needs a key-recovery design. Recommended review item before launch (consider client-side encryption with a user-held key if GMI's risk assessment requires it).

---

## Notifications

| Type | How |
|---|---|
| Appointment confirmed / rescheduled / updated | Database trigger → `notifications` row → realtime → on-device notification |
| Appointment reminder, upcoming activity | `private.send_due_reminders()` every 15 min via `pg_cron` (24 h before) + local reminder 1 h before confirmed appointments |
| Programme registration confirmed | Trigger on `programme_registrations` |
| New learning resource | Trigger when a resource is published (respects the student's preference) |

- Text is always generic (e.g. *"Your appointment request has been confirmed."*). No mood, journal or appointment details are sent.
- Android notifications use `visibility: private`, so the lock screen shows only "GMI MindSpace".
- Students can turn off reminders, activity updates, new-resource alerts and push delivery. Essential confirmations stay in the in-app list.
- **Remote push (FCM)** is prepared but not enabled: see `lib/features/notifications/data/push_messaging_service.dart` and `supabase/functions/send-push/`.

---

## Testing

| Suite | Command | Result (2026-11-23) |
|---|---|---|
| Static analysis | `flutter analyze` | No issues |
| Unit tests | `flutter test test/unit` | 46 passed: validators, PDF file checks, role routing, mood statistics, error mapping, content rules |
| Widget tests | `flutter test test/widget` | 84 passed: login/registration and counsellor sign-up validation, PDF attach / replace / remove / open, emailed-code step, show/hide password, role routing, logout, session expiry, mood check-in, journal create + delete confirmation, appointment request + double-booking message, programme registration, feedback, breathing start/stop, cross-tab navigation |
| UI / responsive | included above | 7 device sizes (320 × 568 → iPad, plus landscape), keyboard open, 130 % text, dark mode, 48 dp tap targets, text contrast |
| Database RLS | `bash supabase/tests/run_local.sh` | **90 / 90 checks passed** with fictional accounts (students, counsellors, admins, counsellor sign-ups, PDF storage access) on PostgreSQL 16 |
| Device workflows | `flutter test integration_test/app_flow_test.dart -d <device>` | **3 / 3 passed on the Android emulator** (Medium_Phone, emulator-5554): student login → mood check-in → journal → logout; counsellor routing; session expiry. Uses in-memory data, not a live server. |
| Live smoke test | `integration_test/live_smoke_test.dart` | **1 / 1 passed (2026-11-24)** on the emulator against `gmi-mindspace-dev`: login, navigation, all six student modules, data written and read back, sign-out, counsellor login |
| Live Supabase security | `integration_test/supabase_security_test.dart` | **6 / 6 passed (2026-11-24)** with fictional accounts on `gmi-mindspace-dev` |
| Release APK (manual) | adb on the emulator | Session persists after restart; friendly offline messages at launch, mid-session and at login. See [docs/TESTING_REPORT.md](docs/TESTING_REPORT.md) |

The RLS suite proves, among others, that a student cannot read or edit another student's journal or
mood records, that counsellors and admins cannot read journals or mood notes, that a student cannot make
themselves a counsellor (directly or through the RPC), that unauthorised users cannot publish resources,
that unassigned counsellors cannot see or change an appointment, that double booking fails, and that the
audit log cannot be forged or deleted.

The local suite uses `supabase/tests/supabase_shim.sql`, which recreates the minimum of Supabase's
`auth`/`storage` schemas on plain PostgreSQL. **Do not run the shim on a real project.**

---

## Readiness

**Verified:** static analysis, 130 Flutter tests, 90 database security checks, migrations apply cleanly
on PostgreSQL 16 and on the Supabase dev project (signed-out access denied), a **signed release APK**
(`my.edu.gmi.mindspace`, 1.0.0+1) builds and runs, 3 integration workflows pass on the Android emulator,
and the live smoke test (6 student modules) and live security test (6 checks) pass against the dev
project with fictional accounts. Details: [docs/TESTING_REPORT.md](docs/TESTING_REPORT.md).

**Not yet verified, required before any real use** (full list: [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md)):

1. Create a separate **production** Supabase project (the APK currently points at the dev project).
2. Run the app on real Android phones and on iOS (needs a Mac), using the checklist in the testing report.
3. GMI Counselling Unit to **verify every emergency number and opening hour** in `lib/core/constants/emergency_contacts.dart`.
4. Privacy / PDPA review, data-retention policy, and the encryption decision above.
5. Configure FCM (optional). (Release signing, app icon and splash screen are done; no store listing is planned.)
6. Hardening items found in self-review:
   - Sessions are stored by supabase_flutter in SharedPreferences (app sandbox). Consider a
     Keychain / Keystore-backed storage.
   - Online meeting links of published programmes are readable by any signed-in student through
     the API (the app only displays them after registration). Move `online_url` behind an RPC if
     links must stay private.
7. Accessibility review with screen readers (TalkBack / VoiceOver).

Until these are done, use only fictional data.
