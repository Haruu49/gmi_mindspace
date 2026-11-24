-- ============================================================================
-- GMI MindSpace · 008 · Notifications
--
-- Notifications are created ONLY by server-side triggers / scheduled jobs.
-- Their text is deliberately generic ("You have an appointment update") so a
-- lock-screen preview never reveals appointment details, moods or journal
-- content. Details are shown only inside the app after sign-in.
-- ============================================================================

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  type public.notification_type not null,
  title text not null check (char_length(title) between 1 and 80),
  body text not null check (char_length(body) between 1 and 200),
  -- Only opaque ids for in-app navigation, e.g. {"appointment_id": "..."}.
  data jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index notifications_user_idx on public.notifications (user_id, created_at desc);

create table public.notification_preferences (
  user_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  -- Essential messages (appointment confirmations / changes, registration
  -- confirmations) are always delivered in-app; these toggles cover the rest.
  appointment_reminders boolean not null default true,
  programme_updates boolean not null default true,
  new_resources boolean not null default true,
  push_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

create trigger notification_preferences_set_updated_at
  before update on public.notification_preferences
  for each row execute function private.set_updated_at();

-- FCM device tokens (prepared for remote push; see supabase/functions/send-push).
create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  token text not null check (char_length(token) between 20 and 4096),
  platform text not null check (platform in ('android', 'ios')),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  constraint device_tokens_token_key unique (token)
);
create index device_tokens_user_idx on public.device_tokens (user_id);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.notifications enable row level security;

create policy "notifications: owner reads"
  on public.notifications for select to authenticated
  using (user_id = (select auth.uid()));
-- Owner can only set read_at (column grant in migration 010).
create policy "notifications: owner marks read"
  on public.notifications for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy "notifications: owner deletes"
  on public.notifications for delete to authenticated
  using (user_id = (select auth.uid()));

alter table public.notification_preferences enable row level security;

create policy "prefs: owner reads"
  on public.notification_preferences for select to authenticated
  using (user_id = (select auth.uid()));
create policy "prefs: owner creates"
  on public.notification_preferences for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy "prefs: owner updates"
  on public.notification_preferences for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

alter table public.device_tokens enable row level security;

create policy "tokens: owner reads"
  on public.device_tokens for select to authenticated
  using (user_id = (select auth.uid()));
create policy "tokens: owner registers"
  on public.device_tokens for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy "tokens: owner refreshes"
  on public.device_tokens for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy "tokens: owner removes"
  on public.device_tokens for delete to authenticated
  using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function private.notify(
  p_user uuid,
  p_type public.notification_type,
  p_title text,
  p_body text,
  p_data jsonb default '{}'::jsonb
)
returns void language sql security definer set search_path = ''
as $$
  insert into public.notifications (user_id, type, title, body, data)
  values (p_user, p_type, p_title, p_body, coalesce(p_data, '{}'::jsonb));
$$;

-- Returns true when the user has not switched this optional category off.
create or replace function private.wants(p_user uuid, p_pref text)
returns boolean language plpgsql stable security definer set search_path = ''
as $$
declare
  v boolean;
begin
  execute format(
    'select %I from public.notification_preferences where user_id = $1', p_pref)
    into v using p_user;
  return coalesce(v, true);
end;
$$;

revoke all on function private.notify(uuid, public.notification_type, text, text, jsonb) from public;
revoke all on function private.wants(uuid, text) from public;

-- Appointment changes -> student / counsellor notifications (generic text).
create or replace function private.on_appointment_change()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  v_data jsonb := jsonb_build_object('appointment_id', new.id);
begin
  if tg_op = 'INSERT' then
    perform private.notify(new.counsellor_id, 'appointment_update',
      'New appointment request', 'A student has requested an appointment.', v_data);
    return new;
  end if;

  if new.starts_at is distinct from old.starts_at then
    perform private.notify(new.student_id, 'appointment_rescheduled',
      'Appointment rescheduled', 'Your appointment time has changed. Open MindSpace to see it.', v_data);
  elsif new.status is distinct from old.status then
    if new.status = 'confirmed' then
      perform private.notify(new.student_id, 'appointment_confirmed',
        'Appointment confirmed', 'Your appointment request has been confirmed.', v_data);
    elsif new.status in ('rejected', 'cancelled') and old.status in ('pending', 'confirmed')
          and (select auth.uid()) = new.counsellor_id then
      perform private.notify(new.student_id, 'appointment_update',
        'Appointment update', 'There is an update to your appointment. Open MindSpace for details.', v_data);
    elsif new.status = 'cancelled' and (select auth.uid()) = new.student_id then
      perform private.notify(new.counsellor_id, 'appointment_update',
        'Appointment cancelled', 'A student has cancelled an appointment.', v_data);
    end if;
  elsif new.reschedule_requested and not old.reschedule_requested then
    perform private.notify(new.counsellor_id, 'appointment_update',
      'Reschedule requested', 'A student has asked to reschedule an appointment.', v_data);
  end if;
  return new;
end;
$$;

create trigger appointments_notify
  after insert or update on public.appointments
  for each row execute function private.on_appointment_change();

create or replace function private.on_registration_change()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if new.status = 'registered'
     and (tg_op = 'INSERT' or old.status is distinct from 'registered') then
    perform private.notify(new.student_id, 'programme_registration',
      'Registration confirmed', 'You are registered for a well-being activity.',
      jsonb_build_object('programme_id', new.programme_id));
  end if;
  return new;
end;
$$;

create trigger programme_registrations_notify
  after insert or update of status on public.programme_registrations
  for each row execute function private.on_registration_change();

-- Newly published resources -> students who keep "new resources" on.
create or replace function private.on_resource_published()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if new.published and (tg_op = 'INSERT' or not old.published) then
    insert into public.notifications (user_id, type, title, body, data)
    select r.user_id, 'new_resource', 'New in the Learning Hub',
           'A new well-being resource is available.',
           jsonb_build_object('resource_id', new.id)
    from public.user_roles r
    join public.profiles p on p.id = r.user_id and p.is_active
    where r.role = 'student' and private.wants(r.user_id, 'new_resources');
  end if;
  return new;
end;
$$;

create trigger resources_notify_published
  after insert or update of published on public.resources
  for each row execute function private.on_resource_published();

-- Reminders ~24h ahead. Idempotent: safe to run every 15 minutes.
create or replace function private.send_due_reminders()
returns integer language plpgsql security definer set search_path = ''
as $$
declare
  v_count integer := 0;
  v_rows integer;
begin
  with due as (
    update public.appointments a
       set reminder_sent_at = now()
     where a.status = 'confirmed'
       and a.reminder_sent_at is null
       and a.starts_at between now() and now() + interval '24 hours'
    returning a.id, a.student_id
  )
  insert into public.notifications (user_id, type, title, body, data)
  select d.student_id, 'appointment_reminder', 'Appointment reminder',
         'You have an appointment coming up. Open MindSpace for details.',
         jsonb_build_object('appointment_id', d.id)
  from due d
  where private.wants(d.student_id, 'appointment_reminders');
  get diagnostics v_rows = row_count;
  v_count := v_count + v_rows;

  insert into public.notifications (user_id, type, title, body, data)
  select g.student_id, 'programme_upcoming', 'Activity starting soon',
         'A well-being activity you registered for starts within 24 hours.',
         jsonb_build_object('programme_id', p.id)
  from public.programme_registrations g
  join public.programmes p on p.id = g.programme_id
  where g.status = 'registered'
    and p.status = 'published'
    and p.starts_at between now() and now() + interval '24 hours'
    and private.wants(g.student_id, 'programme_updates')
    and not exists (
      select 1 from public.notifications n
      where n.user_id = g.student_id and n.type = 'programme_upcoming'
        and n.data ->> 'programme_id' = p.id::text
    );
  get diagnostics v_rows = row_count;
  return v_count + v_rows;
end;
$$;

revoke all on function private.send_due_reminders() from public;

-- Schedule reminders with pg_cron when it is available (Supabase: enable it
-- under Database > Extensions). Skipped silently elsewhere.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    perform cron.schedule('mindspace-reminders', '*/15 * * * *',
                          'select private.send_due_reminders()');
  end if;
end $$;
