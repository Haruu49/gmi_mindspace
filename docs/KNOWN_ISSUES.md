# GMI MindSpace – Known issues

Status on 2026-11-24. Severity: **High** = must be fixed before any real student uses the app;
**Medium** = fix before wider testing; **Low** = improvement.

## High

| # | Issue | Detail | What to do |
|---|---|---|---|
| H1 | Emergency contacts not verified | `lib/core/constants/emergency_contacts.dart` lists 999, 112, Befrienders KL and Talian HEAL 15555. They are public numbers but have **not been checked by the GMI Counselling Unit**. The GMI Counselling Unit entry has **no phone number** and says "Office hours (check with Student Affairs)". | Counselling Unit verifies every number and the opening hours; add the unit's real phone number. |
| H2 | No production Supabase project | The signed APK and the iOS configuration point at `gmi-mindspace-dev`, which also holds fictional test accounts and sample content. | Create a separate production project, apply all migrations, build with a production `env/*.json`. |
| H3 | Privacy / PDPA review not done | No formal review under Malaysia's Personal Data Protection Act, no data-retention period for mood and journal entries, no documented deletion-on-request process. | Institution's data-protection officer reviews; decide retention and deletion. |
| H4 | No administrator on the dev project | `user_roles` has 0 admins, so **Admin ▸ User accounts / Audit log / Settings** cannot be used. | Promote one staff account (README › Supabase setup, step 7). |
| H5 | Counsellor sign-up email setup not done | Migration 015 is applied, but the *Confirm signup* template does not yet contain `{{ .Token }}` and no custom SMTP is configured, so counsellors would not receive a code. | Dashboard steps in [DEPLOYMENT.md](DEPLOYMENT.md#4-supabase-checklist-for-each-environment). |

## Medium

| # | Issue | Detail |
|---|---|---|
| M1 | Not tested on a physical Android phone | All Android testing so far ran on the emulator (`Medium_Phone`, Android 17 / API 37). Older Android versions (minimum supported: 7.0) and manufacturer skins (Samsung, Xiaomi) are untested. |
| M2 | iOS never built or run | Configured on Linux; needs a Mac with Xcode for the first build, simulator and iPhone test. |
| M3 | Accepted risk: any `@gmi.edu.my` mailbox can become a counsellor | Decided by the project owner. Every promotion is audited; admins can demote / deactivate. |
| M4 | Leaked-password protection off | Supabase Auth ▸ Password security. One click in the dashboard. |
| M5 | Online meeting links readable through the API | `programmes.online_url` of published programmes can be read by any signed-in student through the API; the app shows it only after registration. Move it behind a function if links must stay private. |
| M6 | Session stored in SharedPreferences | supabase_flutter keeps the session in app-private storage, not Android Keystore / iOS Keychain. Consider secure storage. |
| M7 | Screen-reader review not done | Automated checks cover contrast, 48 dp tap targets, 130 % text and 7 screen sizes. No TalkBack / VoiceOver walkthrough has been done. |
| M8 | Signing key backup | The Android release key exists only on the development laptop (`~/.gmi-mindspace-signing/`). If the laptop is lost before it is backed up, installed copies cannot be updated. |

## Low

| # | Issue | Detail |
|---|---|---|
| L1 | Double notification-permission request | If a second account signs in while Android's "Allow notifications?" dialog is still open, the app asks again and logs `permissionRequestInProgress`. Harmless (caught), no user-visible error. |
| L2 | Staff ID visible to signed-in users | `profiles.staff_id` of counsellors can be read by signed-in users through the existing "read counsellor profiles" policy. Low sensitivity. |
| L3 | Supabase advisor warnings | 20 "SECURITY DEFINER function executable by authenticated" (intended: each checks the caller's role); 21 unused indexes and 7 "multiple permissive policies" (expected on a near-empty database). |
| L4 | APK size | Universal APK is about 63 MB. Split-per-ABI APKs (~25 MB each) are possible but make sideloading harder. |
| L5 | Sample content in the dev database | 5 Learning Hub resources and 3 programmes from `supabase/seed/seed.sql`. Review or replace before real use. |
| L6 | Push notifications (FCM) not configured | Reminders work as local notifications and in-app notifications; remote push is optional and not set up. |
