# GMI MindSpace – Database documentation

Supabase (PostgreSQL) with Row Level Security (RLS) on **every** table. The app talks to the
database only with the publishable key, so RLS and column grants are what keep data private.
Schema source of truth: `supabase/migrations/` (16 files, applied in filename order).
This document was checked against the live `gmi-mindspace-dev` project on 2026-11-24.

---

## 1. Principles

1. **Roles live in `user_roles`**, never in user-editable sign-up metadata. Only the database
   changes a role: `admin_set_user_role()` (audited) or a verified counsellor sign-up (migration 015).
2. **Private by default.** Mood entries and journal entries have *owner-only* policies. No
   counsellor or administrator policy exists for them.
3. **Workflows go through functions.** Appointments, programme registrations and attendance are
   never written directly by clients. `SECURITY DEFINER` functions check ownership, assignment
   and allowed state changes, then write.
4. **Least privilege.** Migration 010 revokes everything, then grants table and column access
   one by one. Signed-out (`anon`) users get nothing.
5. **Deactivated accounts have no role.** `private.current_app_role()` returns null for an
   inactive profile, so every policy denies them.

## 2. Migrations

| # | File | Contents |
|---|---|---|
| 001 | `foundation` | Extensions, `private` schema, shared enums, `set_updated_at()` |
| 002 | `profiles_and_roles` | `profiles`, `user_roles`, role helper functions, sign-up trigger |
| 003 | `mood_and_journal` | `mood_entries`, `journal_entries`, `mood_share_consents`, `get_shared_mood_summary()` |
| 004 | `counselling_tables` | `counsellor_availability`, `appointments`, `appointment_notes`, `appointment_list` view |
| 005 | `counselling_workflow` | Booking, cancellation, reschedule and status functions |
| 006 | `learning_hub` | `resources`, `resource_bookmarks`, `resource_views`, image storage bucket |
| 007 | `programmes` | `programmes`, `programme_registrations`, `feedback` and their functions |
| 008 | `notifications` | `notifications`, `notification_preferences`, `device_tokens`, triggers, reminder cron |
| 009 | `admin_audit_reports` | `audit_logs`, `app_settings`, admin functions, aggregated reports |
| 010 | `grants` | Table and column grants for the Data API |
| 011 | `counsellor_directory` | `list_counsellors()` |
| 012 | `realtime_notifications` | Realtime publication for `notifications` |
| 013 | `resource_views_upsert` | Upsert support for recently viewed |
| 014 | `fk_indexes` | Indexes on foreign keys |
| 015 | `counsellor_signup` | `profiles.staff_id`, trigger promoting verified `@gmi.edu.my` counsellor sign-ups |
| 016 | `learning_files` | PDF attachments: `resources.file_path/file_name/file_size_bytes`, private `learning-files` bucket and its policies |

## 3. Tables

| Table | Purpose | Key columns | Who can access (RLS) |
|---|---|---|---|
| `profiles` | Basic account details, one per auth user | `full_name`, `student_id`, `staff_id`, `programme_of_study`, `avatar_url`, `is_active` | Own row · counsellor names (for booking) · counsellors: students they serve · admins: all. Users update only name, student ID, programme, avatar. |
| `user_roles` | The only source of authorisation | `role` (`app_role`), `can_manage_content`, `assigned_by` | Read own · admins read all · **no client writes** |
| `mood_entries` | Mood check-ins | `mood` (`mood_type`), `reason` (`mood_reason`), `notes` | **Owner only** |
| `journal_entries` | Private journal | `title`, `content`, `entry_date`, `prompt`, `is_gratitude` | **Owner only** |
| `mood_share_consents` | Student lets one counsellor see mood **counts** | `counsellor_id`, `period_days`, `expires_at`, `revoked_at` | Student manages own · named counsellor reads |
| `counsellor_availability` | Bookable time slots | `starts_at`, `ends_at`, `location`, `is_active` | Counsellor manages own; overlapping slots blocked |
| `appointments` | Counselling appointments | `student_id`, `counsellor_id`, `appointment_type`, `status`, `starts_at`, `student_reason`, `status_reason` | Student reads own · assigned counsellor reads · writes only via functions. Exclusion constraints prevent double booking. |
| `appointment_notes` | Counsellor's private notes | `appointment_id`, `note` | Author counsellor only |
| `resources` | Learning Hub content | `title`, `category`, `format`, `content`, `media_url`, `published`, `file_path`, `file_name`, `file_size_bytes` (optional PDF) | Active users read published · content managers manage. A Download needs a link **or** a PDF; a video needs a link. |
| `resource_bookmarks` | Saved resources | `user_id`, `resource_id` | Owner only |
| `resource_views` | Recently viewed | `user_id`, `resource_id`, `viewed_at` | Owner only |
| `programmes` | Well-being activities | `title`, `mode`, `location`, `online_url`, `starts_at`, `capacity`, `status` | Active users read non-drafts · counsellors manage |
| `programme_registrations` | Sign-ups and attendance | `programme_id`, `student_id`, `status` | Student reads own · counsellors read · writes via functions |
| `feedback` | Programme feedback | `rating`, `comment`, `is_anonymous` | Student submits once (if registered and started) · reads own |
| `notifications` | In-app notifications | `type`, `title`, `body`, `read_at` | Owner only |
| `notification_preferences` | Reminder settings | `appointment_reminders`, `programme_updates`, `new_resources`, `push_enabled` | Owner only |
| `device_tokens` | Push tokens (FCM, optional) | `token`, `platform` | Owner only |
| `audit_logs` | Administrative audit trail | `actor_id`, `action`, `target_user_id`, `details` | Admins read · nobody can write directly |
| `app_settings` | App-wide settings | `key`, `value` | Read by active users · changed via `admin_update_setting()` |

View: `appointment_list` (`security_invoker`) – appointment lists without the student's note
and without counsellor notes.

## 4. Enumerations

| Type | Values |
|---|---|
| `app_role` | student, counsellor, admin |
| `mood_type` | very_happy, good, neutral, sad, stressed |
| `mood_reason` | academic_pressure, family, relationships, financial, personal, health, other |
| `appointment_type` | individual_counselling, academic_support, emotional_wellbeing, other_support |
| `appointment_status` | pending, confirmed, rejected, cancelled, completed |
| `resource_category` | understanding_mental_health, anxiety_awareness, stress_management, depression_awareness, self_esteem, emotional_intelligence, healthy_relationships, academic_burnout, sleep_wellbeing, help_seeking |
| `resource_format` | article, infographic, video, faq, download |
| `programme_mode` | online, physical, hybrid |
| `programme_status` | draft, published, cancelled, completed |
| `registration_status` | registered, cancelled, attended, absent |
| `notification_type` | appointment_confirmed, appointment_rescheduled, appointment_reminder, appointment_update, programme_registration, programme_upcoming, new_resource, general |

## 5. Functions the app calls (RPC)

All are `SECURITY DEFINER` with `search_path = ''` and check the caller's role inside. Supabase's
security advisor lists them as "executable by authenticated" warnings; that is intended.

| Area | Functions |
|---|---|
| Counselling | `get_open_slots`, `request_appointment`, `cancel_my_appointment`, `request_reschedule`, `counsellor_set_appointment_status`, `counsellor_reschedule_appointment`, `list_counsellors` |
| Mood sharing | `get_shared_mood_summary` (counts per mood only, while consent is active) |
| Programmes | `register_for_programme`, `cancel_programme_registration`, `mark_attendance`, `get_programme_feedback` (hides names on anonymous feedback) |
| Reports | `counsellor_dashboard_stats`, `programme_participation` (aggregated counts only) |
| Administration | `admin_list_users`, `admin_set_user_role`, `admin_set_account_active`, `admin_set_content_permission`, `admin_update_setting`, `admin_system_health` |

Internal (not callable by clients): `private.handle_new_user` (creates profile + `student` role
on sign-up), `private.promote_verified_counsellor` (migration 015), `private.audit`,
role helpers `private.is_student/is_counsellor/is_admin/current_app_role`.

## 6. Triggers and scheduled jobs

| Trigger / job | Effect |
|---|---|
| `on_auth_user_created` | New auth user → profile + `student` role |
| `on_auth_user_email_confirmed` | Verified `@gmi.edu.my` counsellor sign-up with a valid, unused Staff ID → `counsellor` role, audited |
| Appointment / registration triggers | Generic in-app notifications (no sensitive details) |
| `private.send_due_reminders()` via `pg_cron` every 15 min | 24-hour reminders for appointments and activities |

## 7. Testing the database

`bash supabase/tests/run_local.sh` creates a throwaway PostgreSQL 16 server, applies a local shim
of Supabase's `auth`/`storage` schemas plus every migration, and runs 90 checks with fictional
accounts. **Never run `supabase_shim.sql` against a real project.** Results: see
[TESTING_REPORT.md](TESTING_REPORT.md).

## 8. Storage buckets

| Bucket | Public? | Contents | Limits | Who can read | Who can write |
|---|---|---|---|---|---|
| `learning-media` | Yes (public URLs) | Learning Hub / programme cover images | 5 MB, JPEG / PNG / WebP | Anyone with the URL | Content managers |
| `learning-files` | **No** (private) | Learning Hub PDF materials (`resources/<id>.pdf`) | 20 MB, PDF only | Active users, **only** for files of published resources (via one-hour signed URLs); content managers: all | Content managers |

Unpublishing a resource immediately stops students getting new links to its PDF. A link already
handed out stays valid until it expires (at most one hour).

## 9. Backups and retention

- Free-plan Supabase projects have **no point-in-time recovery**; daily backups depend on the plan.
- A data-retention policy (how long mood and journal entries are kept, and deletion on request)
  has **not** been decided. See [KNOWN_ISSUES.md](KNOWN_ISSUES.md).
