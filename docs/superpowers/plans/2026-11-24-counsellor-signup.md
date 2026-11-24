# Counsellor Sign-up Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a counsellor self-register (full name, Staff ID, `@gmi.edu.my` email, password), receive an emailed 6-digit code, and become a counsellor the moment the code is accepted.

**Architecture:** Supabase email OTP (`signUp` then `verifyOTP(type: signup)`). A new trigger on `auth.users` fires when `email_confirmed_at` goes from null to set; it grants the `counsellor` role only if sign-up metadata says `signup_type = 'counsellor'`, the email domain is exactly `gmi.edu.my`, and the Staff ID is valid and unused. The client never chooses a role.

**Tech Stack:** Flutter (material_ui, Riverpod 3, go_router 18, supabase_flutter 2), PostgreSQL 16 / Supabase, plain-SQL RLS tests via `supabase/tests/run_local.sh`.

**Spec:** `docs/superpowers/specs/2026-11-24-counsellor-signup-design.md`

## Global Constraints

- Domain rule: email must end exactly `@gmi.edu.my` (case-insensitive, trimmed). `@student.gmi.edu.my` and sub-domains never qualify. Constant: `gmi.edu.my`.
- Staff ID: 3–20 letters/digits (`^[A-Za-z0-9]{3,20}$`), stored upper-cased, unique on `upper(staff_id)`.
- Code: exactly 6 digits; resend cooldown 60 seconds.
- Role is only ever set inside the database, only after `email_confirmed_at` is set; it never comes from a client-supplied `role`. Existing check "sign-up metadata `role` is ignored" must still pass.
- Only promote rows whose current role is `student` (never touch admins).
- Student registration is unchanged.
- Flutter binary: `~/development/flutter/bin/flutter`. Tests: `flutter test`, `bash supabase/tests/run_local.sh`.
- Do not commit or push unless the user asks (repo is public).
- Existing style: `AuthScaffold`, `AppTextField`, `AppButton`, `FormErrorText`, `guard()`; user-facing copy is friendly, non-clinical.

## Review Focus

- Look-alike domains: `x@gmi.edu.my.evil.com`, `x@student.gmi.edu.my`, `x@mail.gmi.edu.my` rejected; `X@GMI.EDU.MY` and padded input accepted.
- Staff ID case: `ab123` and `AB123` are the same ID; second registrant is not promoted.
- Code input: pasted `" 123456 "` is accepted after trimming; letters, 5 digits or empty are rejected before any network call.
- Wrong or expired code shows "That code is not right or has expired." (not the "session expired" message).
- Double-tap on submit/verify/resend sends one request (buttons disabled while loading; resend disabled during cooldown).
- Verified email but duplicate Staff ID: user stays student, is signed out, sees the "contact the Counselling Unit" message.

---

### Task 1: Database — staff_id column and promotion trigger

**Files:**
- Create: `supabase/migrations/20261124000015_counsellor_signup.sql`
- Create: `supabase/tests/rls_03_counsellor_signup.sql`
- Modify: `supabase/tests/supabase_shim.sql` (add `email_confirmed_at timestamptz` to `auth.users`)
- Modify: `supabase/tests/run_local.sh` (run `rls_03` after `rls_02`)

**Interfaces:**
- Produces: `public.profiles.staff_id text`; trigger `on_auth_user_email_confirmed` calling `private.promote_verified_counsellor()`; audit actions `counsellor_self_registered`, `counsellor_signup_rejected` (details `{"reason": "domain"|"staff_id_invalid"|"staff_id_taken"}`). Sign-up metadata keys read: `signup_type`, `staff_id`.

- [ ] **Step 1: Shim + test file first.** Add `email_confirmed_at timestamptz` to the shim's `auth.users`. Write `rls_03_counsellor_signup.sql` (start with `reset role;`, reuse `tests.ok`). Fictional users inserted as postgres with `raw_user_meta_data` `{"signup_type":"counsellor","staff_id":"STF001","full_name":"…"}`, then `update auth.users set email_confirmed_at = now()`. Assertions (each a `tests.ok`):
  1. `@gmi.edu.my` + intent, **before** confirmation → role `student`, `staff_id` null.
  2. same user after confirmation → role `counsellor`, `profiles.staff_id = 'STF001'`, one audit row `counsellor_self_registered` for them.
  3. `x@student.gmi.edu.my` with intent, confirmed → stays `student`, audit `counsellor_signup_rejected` reason `domain`.
  4. `X@GMI.EDU.MY`-style mixed case address with intent, confirmed → `counsellor`.
  5. `x@gmi.edu.my.evil.test` with intent → stays `student`.
  6. second user with Staff ID `stf001` (lower case) → stays `student`, audit reason `staff_id_taken`.
  7. invalid Staff ID `a!` → stays `student`, reason `staff_id_invalid`.
  8. user with `@gmi.edu.my` but metadata `{"role":"admin"}` and no `signup_type` → `student` after confirmation.
  9. an existing admin (`erin`) with intent metadata, confirmed → role still `admin`.
  10. as `authenticated` counsellor from (2): `update public.profiles set staff_id = 'HACK1'` raises permission denied (column not granted).
- [ ] **Step 2: Run `bash supabase/tests/run_local.sh`** (after adding `rls_03` to the `-f` list). Expected: fails (column/trigger missing).
- [ ] **Step 3: Write the migration.** Add `staff_id` with CHECK `^[A-Za-z0-9]{3,20}$`, partial unique index on `upper(staff_id)`. Define `private.promote_verified_counsellor()` (`security definer`, `set search_path = ''`, revoke from public) and trigger `on_auth_user_email_confirmed AFTER UPDATE OF email_confirmed_at ON auth.users FOR EACH ROW WHEN (old.email_confirmed_at IS NULL AND new.email_confirmed_at IS NOT NULL)`. Logic order: ignore unless `signup_type = 'counsellor'`; reject `domain` unless `lower(split_part(email,'@',2)) = 'gmi.edu.my'`; reject `staff_id_invalid`; reject `staff_id_taken` when another profile has the same `upper(staff_id)`; otherwise set `profiles.staff_id = upper(id)` and `user_roles.role = 'counsellor' where role = 'student'`, then `private.audit('counsellor_self_registered', new.id, '{}')`. Wrap the two updates in a block that catches `unique_violation` and records `staff_id_taken` (concurrent race). Rejections never raise (verification must still succeed). `handle_new_user()` is unchanged.
- [ ] **Step 4: Run `bash supabase/tests/run_local.sh`.** Expected: `ALL RLS TESTS PASSED` with all earlier 67 checks plus the new ones.

### Task 2: Validators and constants

**Files:**
- Modify: `lib/core/constants/app_constants.dart`, `lib/core/utils/validators.dart`
- Test: `test/unit/validators_test.dart`

**Interfaces:**
- Produces: `AppConstants.counsellorEmailDomain = 'gmi.edu.my'`; `Validators.counsellorEmail(String?) -> String?`, `Validators.staffId(String?) -> String?`, `Validators.verificationCode(String?) -> String?` (null = valid).

- [ ] **Step 1: Write failing tests** in `validators_test.dart`:
  - `counsellorEmail`: `''`→non-null; `'a@gmi.edu.my'`, `'  A@GMI.EDU.MY '`→null; `'a@student.gmi.edu.my'`, `'a@mail.gmi.edu.my'`, `'a@gmi.edu.my.evil.com'`, `'a@example.com'`→non-null; message for wrong domain is `'Please use your GMI counsellor email (name@gmi.edu.my).'`.
  - `staffId`: `''`→`'Please enter your Staff ID.'`; `'ab'`, `'a!bcd'`, 21 chars→`'Staff ID should be 3–20 letters or numbers.'`; `'STF001'`, `' stf001 '`→null.
  - `verificationCode`: `''`→`'Please enter the 6-digit code.'`; `'12345'`, `'12345a'`, `'1234567'`→`'The code is 6 digits.'`; `'123456'`, `' 123456 '`→null.
- [ ] **Step 2: Run** `~/development/flutter/bin/flutter test test/unit/validators_test.dart`. Expected: FAIL (methods undefined).
- [ ] **Step 3: Implement** the three validators and the constant; `counsellorEmail` calls `email()` first, then compares the part after the last `@` (lower-cased) for equality with the constant.
- [ ] **Step 4: Run the same test.** Expected: PASS.

### Task 3: Auth repository, controller and failure mapping

**Files:**
- Modify: `lib/features/authentication/domain/auth_repository.dart`, `lib/features/authentication/data/supabase_auth_repository.dart`, `lib/features/authentication/presentation/auth_controller.dart`, `lib/core/utils/failure.dart`, `test/helpers/test_app.dart` (FakeAuthRepository)
- Test: `test/widget/auth_screens_test.dart` is extended in Task 4; this task adds `test/unit/domain_test.dart`-style unit tests in `test/unit/auth_failure_test.dart` (new)

**Interfaces:**
- Consumes: Task 2 validators (UI only).
- Produces:
  - `AuthRepository.signUpCounsellor({required String fullName, required String staffId, required String email, required String password}) -> Future<void>`; sends metadata `{'signup_type':'counsellor','full_name':trimmed,'staff_id':trimmed upper-case}`, `emailRedirectTo: Env.authRedirectUrl`; if the response has a session (email confirmation off) it signs out and throws `AppFailure('Counsellor sign-up is not available right now. Please contact the GMI Counselling Unit.')`.
  - `AuthRepository.verifyEmailCode({required String email, required String code}) -> Future<void>` (`verifyOTP(type: OtpType.signup)`, email lower-cased, code trimmed).
  - `AuthRepository.resendEmailCode(String email) -> Future<void>` (`auth.resend(type: OtpType.signup, email:)`).
  - `AuthController.registerCounsellor({fullName, staffId, email, password}) -> Future<void>`, `verifyCounsellorCode({required String email, required String code}) -> Future<void>`, `resendCounsellorCode(String email) -> Future<void>`.
  - `verifyCounsellorCode` mirrors `signIn`: set `_signingIn`, verify, `fetchCurrentProfile`; if role is still `AppRole.student` set `_userSignedOut = true`, sign out and throw `AppFailure('Your email is verified, but counsellor access could not be activated. Please contact the GMI Counselling Unit.', kind: FailureKind.permission)`; otherwise `state = AuthSignedIn(profile)`.
  - `FakeAuthRepository`: `final List<String> counsellorSignups`, `String validCode = '123456'`, `final Set<String> takenStaffIds`, `final List<String> resent`; `verifyEmailCode` throws `AppFailure('That code is not right or has expired. Request a new one.', kind: FailureKind.auth)` on a wrong code; on the right code it signs in a new counsellor profile (or a student profile when the staff ID is in `takenStaffIds`) and emits `AuthEvent.signedIn`.

- [ ] **Step 1: Write failing test** `test/unit/auth_failure_test.dart`: `AppFailure.from(AuthException('Token has expired or is invalid'))` has message `'That code is not right or has expired. Request a new one.'` and `kind == FailureKind.auth` (not `sessionExpired`); `AuthException('Invalid login credentials')` still maps to the old message.
- [ ] **Step 2: Run it.** Expected: FAIL (maps to sessionExpired).
- [ ] **Step 3: Implement** the failure mapping **before** the existing `jwt`/`expired` branch in `_fromAuth` (match `token` plus `invalid` or `expired`), then the repository, controller and fake as specified above.
- [ ] **Step 4: Run** `~/development/flutter/bin/flutter test test/unit` and `~/development/flutter/bin/flutter analyze`. Expected: PASS, no analyzer errors.

### Task 4: Counsellor sign-up UI, routes and login link

**Files:**
- Create: `lib/features/authentication/presentation/counsellor_register_screen.dart`
- Modify: `lib/core/routing/app_routes.dart` (`counsellorRegister = '/register/counsellor'`, add to `publicRoutes`), `lib/core/routing/app_router.dart`, `lib/features/authentication/presentation/login_screen.dart`
- Test: `test/widget/auth_screens_test.dart`, `test/unit/route_guard_test.dart`

**Interfaces:**
- Consumes: Task 2 validators, Task 3 controller methods and `FakeAuthRepository`.
- Produces: `class CounsellorRegisterScreen extends ConsumerStatefulWidget` with widget keys `counsellor_register_name`, `counsellor_register_staff_id`, `counsellor_register_email`, `counsellor_register_password`, `counsellor_register_confirm`, `counsellor_register_submit`, and (code step) `counsellor_code`, `counsellor_code_submit`, `counsellor_code_resend`.

- [ ] **Step 1: Write failing tests.**
  - `route_guard_test`: signed-out user at `AppRoutes.counsellorRegister` → `null` (allowed); signed-in student at it → redirected to student home.
  - `auth_screens_test` group "Counsellor sign-up": (a) empty submit shows `'Please enter your Staff ID.'` and the name/email errors; (b) `name@student.gmi.edu.my` shows `'Please use your GMI counsellor email (name@gmi.edu.my).'`; (c) valid form switches to the code step (text contains the email, `counsellor_code` field present) and `fake.counsellorSignups` has one entry; (d) wrong code `'000000'` shows `'That code is not right or has expired. Request a new one.'` and stays on the code step; (e) `'12345'` shows `'The code is 6 digits.'` and does not call the repository; (f) right code `'123456'` with `pumpFullApp` lands on the counsellor dashboard; (g) duplicate Staff ID (`fake.takenStaffIds.add('STF001')`) shows the "email is verified, but counsellor access could not be activated" message and `signOutCalls == 1`; (h) resend button is disabled right after sign-up and enabled after `tester.pump(const Duration(seconds: 61))`, and tapping it adds to `fake.resent`; (i) Counsellor Login shows a "Sign up" button that opens the sign-up screen.
- [ ] **Step 2: Run** `~/development/flutter/bin/flutter test test/widget/auth_screens_test.dart test/unit/route_guard_test.dart`. Expected: FAIL (route/screen missing).
- [ ] **Step 3: Implement.** Two-state screen in the style of `RegisterScreen` (`AuthScaffold`, icon `Icons.volunteer_activism_rounded`, accent `AppColors.sageDeep`): form state (full name, Staff ID with upper-case capitalisation, counsellor email, password, confirm password; no privacy checkbox), then code state (subtitle "We sent a 6-digit code to <email>."; code field numeric, max length 6; Verify button; "Resend code" text button with 60 s `Timer.periodic` countdown, cancelled in `dispose`). All buttons disabled while a request runs. Register the route in `app_router.dart` the same way as `AppRoutes.register`. In `login_screen.dart` replace the staff-only "Counsellor accounts are created and approved by a GMI administrator." text with the same Wrap pattern as the student branch: "New counsellor?" + text button "Sign up" → `context.pushReplacement(AppRoutes.counsellorRegister)`.
- [ ] **Step 4: Run** the same tests, then `~/development/flutter/bin/flutter test` and `~/development/flutter/bin/flutter analyze`. Expected: all PASS; fix any existing test that asserted the old administrator-only sentence.

### Task 5: Docs

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update README.** Replace step 8 (line ~174, "Counsellors: invite them under Authentication ▸ Users…") with the new flow plus the two dashboard steps (edit *Confirm signup* template to include `{{ .Token }}` while keeping `{{ .ConfirmationURL }}`; configure custom SMTP; keep *Confirm email* on). Update the `user_roles` row in the RLS table (sign-up is student unless verified `@gmi.edu.my` counsellor sign-up), the counsellor feature row, and the test counts with the real numbers from Tasks 1 and 4. Mention the accepted risk and that admins can still demote/deactivate.
- [ ] **Step 2: Verify.** Re-run `bash supabase/tests/run_local.sh` and `~/development/flutter/bin/flutter test`; copy the actual counts into the README. Expected: both green.
