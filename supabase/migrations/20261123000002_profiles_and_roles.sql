-- ============================================================================
-- GMI MindSpace · 002 · Profiles and roles
-- ============================================================================

-- ---------------------------------------------------------------------------
-- profiles: one row per auth user (basic, non-sensitive account details).
-- ---------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null
    check (char_length(btrim(full_name)) between 2 and 80),
  student_id text
    check (student_id is null or student_id ~ '^[A-Za-z0-9]{5,20}$'),
  programme_of_study text
    check (programme_of_study is null or char_length(programme_of_study) <= 120),
  avatar_url text
    check (avatar_url is null or char_length(avatar_url) <= 500),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index profiles_student_id_key
  on public.profiles (upper(student_id)) where student_id is not null;

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function private.set_updated_at();

-- ---------------------------------------------------------------------------
-- user_roles: the ONLY source of truth for authorisation.
-- Never derived from user_metadata (which users can edit themselves).
-- One approved role per user.
-- ---------------------------------------------------------------------------
create table public.user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users (id) on delete cascade,
  role public.app_role not null default 'student',
  assigned_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index user_roles_role_idx on public.user_roles (role);

create trigger user_roles_set_updated_at
  before update on public.user_roles
  for each row execute function private.set_updated_at();

-- ---------------------------------------------------------------------------
-- Role helpers (SECURITY DEFINER so policies can read user_roles without
-- recursive RLS). They live in the unexposed `private` schema, take no
-- caller-supplied user id, and only ever describe auth.uid().
-- A deactivated account has no effective role, so every policy denies it.
-- ---------------------------------------------------------------------------
create or replace function private.current_app_role()
returns public.app_role
language sql
stable
security definer
set search_path = ''
as $$
  select r.role
  from public.user_roles r
  join public.profiles p on p.id = r.user_id
  where r.user_id = (select auth.uid())
    and p.is_active
$$;

create or replace function private.is_student()
returns boolean language sql stable security definer set search_path = ''
as $$ select coalesce(private.current_app_role() = 'student', false) $$;

create or replace function private.is_counsellor()
returns boolean language sql stable security definer set search_path = ''
as $$ select coalesce(private.current_app_role() = 'counsellor', false) $$;

create or replace function private.is_admin()
returns boolean language sql stable security definer set search_path = ''
as $$ select coalesce(private.current_app_role() = 'admin', false) $$;

create or replace function private.is_active_user()
returns boolean language sql stable security definer set search_path = ''
as $$ select private.current_app_role() is not null $$;

-- Is `target` a counsellor? (Counsellor names are visible for booking.)
create or replace function private.is_counsellor_account(target uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.user_roles r
    join public.profiles p on p.id = r.user_id
    where r.user_id = target and r.role = 'counsellor' and p.is_active
  )
$$;

revoke all on function private.current_app_role() from public;
revoke all on function private.is_student() from public;
revoke all on function private.is_counsellor() from public;
revoke all on function private.is_admin() from public;
revoke all on function private.is_active_user() from public;
revoke all on function private.is_counsellor_account(uuid) from public;
grant execute on function private.current_app_role() to authenticated;
grant execute on function private.is_student() to authenticated;
grant execute on function private.is_counsellor() to authenticated;
grant execute on function private.is_admin() to authenticated;
grant execute on function private.is_active_user() to authenticated;
grant execute on function private.is_counsellor_account(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- New sign-ups: create the profile and ALWAYS assign the `student` role.
-- Any `role` key a client puts in sign-up metadata is ignored.
-- ---------------------------------------------------------------------------
create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text := btrim(coalesce(new.raw_user_meta_data ->> 'full_name', ''));
  v_student_id text := nullif(btrim(coalesce(new.raw_user_meta_data ->> 'student_id', '')), '');
begin
  if char_length(v_name) < 2 then
    v_name := split_part(coalesce(new.email, 'Student'), '@', 1);
  end if;
  if char_length(v_name) < 2 then
    v_name := 'Student';
  end if;
  if v_student_id is not null and v_student_id !~ '^[A-Za-z0-9]{5,20}$' then
    v_student_id := null;
  end if;

  insert into public.profiles (id, full_name, student_id)
  values (new.id, left(v_name, 80), v_student_id);

  insert into public.user_roles (user_id, role) values (new.id, 'student');
  return new;
end;
$$;

revoke all on function private.handle_new_user() from public;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- ---------------------------------------------------------------------------
-- RLS: profiles
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;

-- Everyone may read their own profile (needed to show name and detect a
-- deactivated account at login).
create policy "profiles: read own"
  on public.profiles for select to authenticated
  using (id = (select auth.uid()));

-- Signed-in, active users may see counsellor names (to book appointments).
create policy "profiles: read counsellor profiles"
  on public.profiles for select to authenticated
  using (private.is_active_user() and private.is_counsellor_account(id));

-- Administrators may read basic account details for account management.
-- profiles holds no mood or journal content.
create policy "profiles: admin read all"
  on public.profiles for select to authenticated
  using (private.is_admin());

-- Users may edit their own basic details. Column grants (end of migration
-- 009) stop them from touching is_active.
create policy "profiles: update own"
  on public.profiles for update to authenticated
  using (id = (select auth.uid()) and private.is_active_user())
  with check (id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- RLS: user_roles – read-only for clients. Role changes go only through
-- public.admin_set_user_role() (migration 008), which audits every change.
-- ---------------------------------------------------------------------------
alter table public.user_roles enable row level security;

create policy "user_roles: read own"
  on public.user_roles for select to authenticated
  using (user_id = (select auth.uid()));

create policy "user_roles: admin read all"
  on public.user_roles for select to authenticated
  using (private.is_admin());
