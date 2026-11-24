# Counsellor sign-up with email verification code (short design)

Date: 2026-11-24 · Status: **awaiting approval**

## Intent
Counsellors create their own account (full name, Staff ID, GMI counsellor email,
password). After sign-up, GMI MindSpace emails a verification code. When they enter
it correctly they become a counsellor and land on the counsellor dashboard. No admin
step in between (the requester's decision).

## Goals
- New "Counsellor sign-up" screen reachable from Counsellor Login.
- 6-digit emailed code screen with resend.
- Role becomes `counsellor` automatically once the mailbox is proven.

## Non-goals
- Changing student registration (still link-based; the shared email will show both
  a link and a code).
- Admin approval queue. Admins can still demote or deactivate through the existing
  *Admin > User accounts* screen, and every promotion is audited.
- Checking Staff IDs against an HR list (none exists).

## Anti-goals (failure even if it "works")
- A client being able to name its own role. The role may only change inside the
  database, and only after Supabase has confirmed the email.
- A student-domain address (`@student.gmi.edu.my`) becoming a counsellor.

## Accepted risk (requester's decision)
Anyone who owns an `@gmi.edu.my` mailbox (e.g. a lecturer) can self-register as a
counsellor, and counsellors can see appointment, programme and consented mood-summary
data. Mitigations that already exist: audit log entry, admin demote/deactivate.

## Approaches considered
1. **Supabase built-in email OTP + database trigger on email confirmation. (chosen)**
   No new infrastructure; promotion is atomic with verification.
2. Edge Function with a custom mail provider and own code store. Rejected: secrets,
   provider, expiry/limits to build and maintain.
3. Sign up as student, then call a `claim_counsellor_role()` RPC. Rejected: a crash
   between verification and claim leaves a verified account without the role.

## Design
**Database** (new migration `…015_counsellor_signup.sql`)
- `profiles.staff_id text` (3–20 letters/digits), unique on `upper(staff_id)`.
  Not editable by users (column grants), same as `is_active`.
- `private.handle_new_user()` is unchanged in what it trusts: always `student`.
  It may copy a well-formed `staff_id` from sign-up metadata *only* as display data.
- New trigger on `auth.users` `AFTER UPDATE OF email_confirmed_at` (null -> not null):
  if metadata `signup_type = 'counsellor'`, email domain is exactly `gmi.edu.my`
  (case-insensitive; no sub-domains), and the Staff ID is valid and unused, then set
  the role to `counsellor`, save `staff_id`, write audit `counsellor_self_registered`.
  If the Staff ID is already used, do not promote; audit `counsellor_signup_rejected`.

**App**
- Routes `/register/counsellor` (public) and a code step (same screen, second state).
- `AuthRepository.signUpCounsellor(...)` -> `auth.signUp` with metadata
  `signup_type`, `full_name`, `staff_id`; `verifyEmailCode(email, code)` ->
  `auth.verifyOTP(type: signup)`; `resendEmailCode(email)`.
- `Validators.counsellorEmail` (must end `@gmi.edu.my`), `Validators.staffId`.
- After a correct code the existing auth listener loads the profile and the router
  sends a counsellor to `/counsellor`. If the profile is still `student` (duplicate
  Staff ID), show "Email verified, but counsellor access could not be activated.
  Please contact the GMI Counselling Unit." and sign out.
- Counsellor Login: replace "accounts are created by an administrator" with a
  "New counsellor? Sign up" link.

**Supabase dashboard (manual, documented in README)**
- Edit *Confirm signup* email template to include `{{ .Token }}` (and keep
  `{{ .ConfirmationURL }}` for students).
- Configure custom SMTP (built-in sender is heavily rate-limited).

## My calls (not discussed; change any you disagree with)
- Password + confirm-password fields are included (needed to sign in later).
- Staff ID format: 3-20 letters/digits.
- Domain rule is the constant `gmi.edu.my`, hard-coded in the migration and
  `AppConstants`; the `Counsellor@gmi.edu.my` in the request is treated as an
  example of the format, not the one allowed address.
- Resend cooldown 60 s on the code screen.

## Tests
- Unit: new validators. Widget: counsellor sign-up form validation, code step,
  duplicate-Staff-ID message, route guard allows the new public route.
- SQL (extends `supabase/tests`): intent+wrong domain stays student; right domain
  but unconfirmed stays student; confirmed right domain becomes counsellor and is
  audited; `@student.gmi.edu.my` stays student; duplicate Staff ID not promoted;
  user cannot edit own `staff_id`; existing "role in metadata is ignored" still passes.

## Left to the builder
Exact wording of screens, how the duplicate-Staff-ID rejection is surfaced, whether
to show Staff ID on the counsellor profile screen.
