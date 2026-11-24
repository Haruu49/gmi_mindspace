-- ============================================================================
-- GMI MindSpace · 009 · Administration, audit log, settings and reports
--
-- Administrators manage ACCOUNTS (roles, activation, content permission,
-- settings). They have no policy on mood_entries, journal_entries,
-- appointment_notes or mood_share_consents, so they cannot read private
-- student content.
-- ============================================================================

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users (id) on delete set null,
  action text not null check (char_length(action) between 3 and 60),
  target_user_id uuid references auth.users (id) on delete set null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index audit_logs_created_idx on public.audit_logs (created_at desc);
create index audit_logs_target_idx on public.audit_logs (target_user_id);

alter table public.audit_logs enable row level security;
-- Read-only for administrators. No insert/update/delete grants for clients:
-- entries are written only by the functions below and cannot be altered.
create policy "audit: admins read"
  on public.audit_logs for select to authenticated
  using (private.is_admin());

create table public.app_settings (
  key text primary key check (key ~ '^[a-z_]{3,50}$'),
  value jsonb not null,
  description text,
  updated_by uuid references auth.users (id) on delete set null,
  updated_at timestamptz not null default now()
);

alter table public.app_settings enable row level security;
create policy "settings: active users read"
  on public.app_settings for select to authenticated
  using (private.is_active_user());

insert into public.app_settings (key, value, description) values
  ('counselling_hours', '"Monday – Friday, 8:30 am – 5:00 pm"', 'Shown on the counselling screen'),
  ('counselling_location', '"Counselling Unit, Student Affairs"', 'Where students meet counsellors'),
  ('support_message', '"You are not alone. Reach out whenever you need to."', 'Dashboard encouragement'),
  ('maintenance_mode', 'false', 'When true the app shows a maintenance notice')
on conflict (key) do nothing;

create or replace function private.audit(p_action text, p_target uuid, p_details jsonb)
returns void language sql security definer set search_path = ''
as $$
  insert into public.audit_logs (actor_id, action, target_user_id, details)
  values ((select auth.uid()), p_action, p_target, coalesce(p_details, '{}'::jsonb));
$$;
revoke all on function private.audit(text, uuid, jsonb) from public;

create or replace function private.require_admin_on_other(p_user uuid)
returns void language plpgsql stable security definer set search_path = ''
as $$
begin
  if not private.is_admin() then
    raise exception 'Only administrators can do this.' using errcode = '42501';
  end if;
  if p_user = (select auth.uid()) then
    raise exception 'You cannot change your own account. Ask another administrator.'
      using errcode = '42501';
  end if;
  if not exists (select 1 from public.user_roles where user_id = p_user) then
    raise exception 'User not found.';
  end if;
end;
$$;
revoke all on function private.require_admin_on_other(uuid) from public;

-- ---------------------------------------------------------------------------
-- Admin RPCs
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_users(
  p_search text default null,
  p_role public.app_role default null
)
returns table (
  id uuid, full_name text, email text, student_id text, role public.app_role,
  is_active boolean, can_manage_content boolean, created_at timestamptz,
  last_sign_in_at timestamptz
)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not private.is_admin() then
    raise exception 'Only administrators can do this.' using errcode = '42501';
  end if;
  return query
    select p.id, p.full_name, u.email::text, p.student_id, r.role, p.is_active,
           r.can_manage_content, p.created_at, u.last_sign_in_at
    from public.profiles p
    join public.user_roles r on r.user_id = p.id
    join auth.users u on u.id = p.id
    where (p_role is null or r.role = p_role)
      and (p_search is null or btrim(p_search) = ''
           or p.full_name ilike '%' || btrim(p_search) || '%'
           or u.email ilike '%' || btrim(p_search) || '%'
           or p.student_id ilike '%' || btrim(p_search) || '%')
    order by p.created_at desc
    limit 200;
end;
$$;

create or replace function public.admin_set_user_role(p_user uuid, p_role public.app_role)
returns void language plpgsql security definer set search_path = ''
as $$
declare
  v_old public.app_role;
begin
  perform private.require_admin_on_other(p_user);
  select role into v_old from public.user_roles where user_id = p_user for update;
  if v_old = p_role then
    return;
  end if;
  if v_old = 'admin' and (select count(*) from public.user_roles where role = 'admin') <= 1 then
    raise exception 'At least one administrator must remain.';
  end if;
  update public.user_roles
     set role = p_role, assigned_by = (select auth.uid())
   where user_id = p_user;
  perform private.audit('role_changed', p_user,
    jsonb_build_object('from', v_old, 'to', p_role));
end;
$$;

create or replace function public.admin_set_account_active(p_user uuid, p_active boolean)
returns void language plpgsql security definer set search_path = ''
as $$
begin
  perform private.require_admin_on_other(p_user);
  update public.profiles set is_active = p_active where id = p_user;
  perform private.audit(case when p_active then 'account_activated' else 'account_deactivated' end,
    p_user, '{}'::jsonb);
end;
$$;

create or replace function public.admin_set_content_permission(p_user uuid, p_allowed boolean)
returns void language plpgsql security definer set search_path = ''
as $$
begin
  perform private.require_admin_on_other(p_user);
  update public.user_roles set can_manage_content = p_allowed where user_id = p_user;
  perform private.audit('content_permission_changed', p_user,
    jsonb_build_object('can_manage_content', p_allowed));
end;
$$;

create or replace function public.admin_update_setting(p_key text, p_value jsonb)
returns void language plpgsql security definer set search_path = ''
as $$
declare
  v_old jsonb;
begin
  if not private.is_admin() then
    raise exception 'Only administrators can do this.' using errcode = '42501';
  end if;
  select value into v_old from public.app_settings where key = p_key for update;
  if not found then
    raise exception 'Unknown setting.';
  end if;
  update public.app_settings
     set value = p_value, updated_by = (select auth.uid()), updated_at = now()
   where key = p_key;
  perform private.audit('setting_changed', null,
    jsonb_build_object('key', p_key, 'from', v_old, 'to', p_value));
end;
$$;

-- Technical health: counts only, no personal content.
create or replace function public.admin_system_health()
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
begin
  if not private.is_admin() then
    raise exception 'Only administrators can do this.' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'checked_at', now(),
    'database_size_mb', round(pg_database_size(current_database()) / 1048576.0, 1),
    'students', (select count(*) from public.user_roles where role = 'student'),
    'counsellors', (select count(*) from public.user_roles where role = 'counsellor'),
    'admins', (select count(*) from public.user_roles where role = 'admin'),
    'inactive_accounts', (select count(*) from public.profiles where not is_active),
    'signups_7d', (select count(*) from public.profiles where created_at > now() - interval '7 days'),
    'pending_appointments', (select count(*) from public.appointments where status = 'pending'),
    'published_resources', (select count(*) from public.resources where published),
    'published_programmes', (select count(*) from public.programmes where status = 'published'),
    'audit_events_24h', (select count(*) from public.audit_logs where created_at > now() - interval '24 hours')
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Counsellor reporting: aggregated engagement only. No diagnoses, no risk
-- scores, no individual mood data. Groups smaller than 5 students are
-- suppressed (null) so nobody can be singled out.
-- ---------------------------------------------------------------------------
create or replace function public.counsellor_dashboard_stats()
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare
  v_me uuid := (select auth.uid());
  v_checkin_users bigint;
begin
  if not private.is_counsellor() then
    raise exception 'Only counsellors can view reports.' using errcode = '42501';
  end if;

  select count(distinct user_id) into v_checkin_users
  from public.mood_entries where created_at > now() - interval '30 days';

  return jsonb_build_object(
    'pending', (select count(*) from public.appointments where counsellor_id = v_me and status = 'pending'),
    'confirmed', (select count(*) from public.appointments where counsellor_id = v_me and status = 'confirmed'),
    'upcoming_7d', (select count(*) from public.appointments where counsellor_id = v_me
                      and status = 'confirmed' and starts_at between now() and now() + interval '7 days'),
    'completed', (select count(*) from public.appointments where counsellor_id = v_me and status = 'completed'),
    'reschedule_requests', (select count(*) from public.appointments where counsellor_id = v_me
                      and reschedule_requested and status in ('pending', 'confirmed')),
    'active_programmes', (select count(*) from public.programmes where status = 'published' and ends_at > now()),
    'programme_registrations', (select count(*) from public.programme_registrations where status in ('registered', 'attended')),
    'programme_attended', (select count(*) from public.programme_registrations where status = 'attended'),
    'programme_absent', (select count(*) from public.programme_registrations where status = 'absent'),
    'average_feedback_rating', (select round(avg(rating)::numeric, 2) from public.feedback),
    'feedback_count', (select count(*) from public.feedback),
    'published_resources', (select count(*) from public.resources where published),
    'resource_bookmarks', (select count(*) from public.resource_bookmarks),
    'checkin_users_30d', case when v_checkin_users >= 5 then v_checkin_users end
  );
end;
$$;

-- Per-programme participation (counts only).
create or replace function public.programme_participation()
returns table (programme_id uuid, title text, starts_at timestamptz, status public.programme_status,
               capacity integer, registered bigint, attended bigint, absent bigint,
               cancelled bigint, avg_rating numeric)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not private.is_counsellor() then
    raise exception 'Only counsellors can view reports.' using errcode = '42501';
  end if;
  return query
    select p.id, p.title, p.starts_at, p.status, p.capacity,
           count(*) filter (where g.status = 'registered'),
           count(*) filter (where g.status = 'attended'),
           count(*) filter (where g.status = 'absent'),
           count(*) filter (where g.status = 'cancelled'),
           (select round(avg(f.rating)::numeric, 2) from public.feedback f where f.programme_id = p.id)
    from public.programmes p
    left join public.programme_registrations g on g.programme_id = p.id
    group by p.id
    order by p.starts_at desc;
end;
$$;

do $$
declare
  fn text;
begin
  foreach fn in array array[
    'public.admin_list_users(text, public.app_role)',
    'public.admin_set_user_role(uuid, public.app_role)',
    'public.admin_set_account_active(uuid, boolean)',
    'public.admin_set_content_permission(uuid, boolean)',
    'public.admin_update_setting(text, jsonb)',
    'public.admin_system_health()',
    'public.counsellor_dashboard_stats()',
    'public.programme_participation()'
  ] loop
    execute format('revoke all on function %s from public, anon', fn);
    execute format('grant execute on function %s to authenticated', fn);
  end loop;
end $$;
