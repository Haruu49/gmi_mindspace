-- ============================================================================
-- GMI MindSpace · 010 · Data API grants
--
-- New Supabase projects no longer expose public tables automatically, and we
-- want least privilege anyway. Start from nothing, then grant exactly what
-- each table needs. RLS (earlier migrations) then decides WHICH rows.
--
-- Column-level INSERT/UPDATE grants stop clients from writing protected
-- columns (user_id, status, is_active, timestamps) even on their own rows.
-- `anon` (signed-out) gets nothing at all.
-- ============================================================================

revoke all on all tables in schema public from anon, authenticated;
revoke all on all functions in schema public from anon;
grant usage on schema public to authenticated;

-- Accounts
grant select on public.profiles to authenticated;
grant update (full_name, student_id, programme_of_study, avatar_url)
  on public.profiles to authenticated;
grant select on public.user_roles to authenticated;

-- Mood & journal (owner-only via RLS)
grant select, delete on public.mood_entries to authenticated;
grant insert (mood, reason, notes) on public.mood_entries to authenticated;
grant update (mood, reason, notes) on public.mood_entries to authenticated;

grant select, delete on public.journal_entries to authenticated;
grant insert (title, content, entry_date, prompt, is_gratitude)
  on public.journal_entries to authenticated;
grant update (title, content, entry_date, prompt, is_gratitude)
  on public.journal_entries to authenticated;

grant select on public.mood_share_consents to authenticated;
grant insert (counsellor_id, period_days) on public.mood_share_consents to authenticated;
grant update (revoked_at) on public.mood_share_consents to authenticated;

-- Counselling (appointments are written only through workflow functions)
grant select, delete on public.counsellor_availability to authenticated;
grant insert (starts_at, ends_at, location, is_active)
  on public.counsellor_availability to authenticated;
grant update (starts_at, ends_at, location, is_active)
  on public.counsellor_availability to authenticated;

grant select on public.appointments to authenticated;
grant select on public.appointment_list to authenticated;

grant select, delete on public.appointment_notes to authenticated;
grant insert (appointment_id, note) on public.appointment_notes to authenticated;
grant update (note) on public.appointment_notes to authenticated;

-- Learning hub
grant select, delete on public.resources to authenticated;
grant insert (title, description, category, format, content, image_url,
              media_url, read_minutes, published)
  on public.resources to authenticated;
grant update (title, description, category, format, content, image_url,
              media_url, read_minutes, published)
  on public.resources to authenticated;

grant select, delete on public.resource_bookmarks to authenticated;
grant insert (resource_id) on public.resource_bookmarks to authenticated;

grant select, delete on public.resource_views to authenticated;
grant insert (resource_id, viewed_at) on public.resource_views to authenticated;
grant update (viewed_at) on public.resource_views to authenticated;

-- Programmes (registrations are written only through workflow functions)
grant select, delete on public.programmes to authenticated;
grant insert (title, description, category, mode, location, online_url,
              starts_at, ends_at, capacity, status, image_url)
  on public.programmes to authenticated;
grant update (title, description, category, mode, location, online_url,
              starts_at, ends_at, capacity, status, image_url)
  on public.programmes to authenticated;

grant select on public.programme_registrations to authenticated;

grant select on public.feedback to authenticated;
grant insert (programme_id, rating, comment, is_anonymous)
  on public.feedback to authenticated;

-- Notifications
grant select, delete on public.notifications to authenticated;
grant update (read_at) on public.notifications to authenticated;

grant select on public.notification_preferences to authenticated;
grant insert (appointment_reminders, programme_updates, new_resources, push_enabled)
  on public.notification_preferences to authenticated;
grant update (appointment_reminders, programme_updates, new_resources, push_enabled)
  on public.notification_preferences to authenticated;

grant select, delete on public.device_tokens to authenticated;
grant insert (token, platform) on public.device_tokens to authenticated;
grant update (platform, last_seen_at) on public.device_tokens to authenticated;

-- Administration (writes only through admin_* functions)
grant select on public.audit_logs to authenticated;
grant select on public.app_settings to authenticated;
