-- ============================================================================
-- GMI MindSpace · 007 · Well-being programmes, registrations, feedback
-- ============================================================================

create table public.programmes (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(btrim(title)) between 3 and 150),
  description text not null check (char_length(btrim(description)) between 10 and 4000),
  category text not null default 'Workshop'
    check (category in ('Campaign', 'Webinar', 'Workshop', 'Challenge',
                        'Quiz', 'Programme', 'Talk')),
  mode public.programme_mode not null default 'physical',
  location text check (location is null or char_length(location) <= 150),
  online_url text check (online_url is null or online_url ~ '^https://'),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  capacity integer check (capacity is null or capacity between 1 and 5000),
  status public.programme_status not null default 'draft',
  image_url text check (image_url is null or char_length(image_url) <= 500),
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at),
  check (mode = 'physical' or online_url is not null),
  check (mode = 'online' or location is not null)
);

create index programmes_status_starts_idx on public.programmes (status, starts_at);

create trigger programmes_set_updated_at
  before update on public.programmes
  for each row execute function private.set_updated_at();

create table public.programme_registrations (
  id uuid primary key default gen_random_uuid(),
  programme_id uuid not null references public.programmes (id) on delete cascade,
  student_id uuid not null references auth.users (id) on delete cascade,
  status public.registration_status not null default 'registered',
  registered_at timestamptz not null default now(),
  cancelled_at timestamptz,
  attendance_marked_at timestamptz,
  updated_at timestamptz not null default now(),
  -- DUPLICATE GUARD: one registration row per student per programme.
  constraint programme_registrations_unique unique (programme_id, student_id)
);

create index programme_registrations_student_idx
  on public.programme_registrations (student_id, registered_at desc);

create trigger programme_registrations_set_updated_at
  before update on public.programme_registrations
  for each row execute function private.set_updated_at();

create table public.feedback (
  id uuid primary key default gen_random_uuid(),
  programme_id uuid not null references public.programmes (id) on delete cascade,
  student_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  comment text check (comment is null or char_length(comment) <= 1000),
  is_anonymous boolean not null default false,
  created_at timestamptz not null default now(),
  constraint feedback_one_per_programme unique (programme_id, student_id)
);

create index feedback_programme_idx on public.feedback (programme_id);

-- Counsellors also see the names of students registered for programmes
-- (needed for attendance). Redefines the helper from migration 004.
create or replace function private.counsellor_has_student(target uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.appointments a
    where a.student_id = target and a.counsellor_id = (select auth.uid())
  ) or exists (
    select 1 from public.programme_registrations g where g.student_id = target
  )
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.programmes enable row level security;

create policy "programmes: active users read non-drafts"
  on public.programmes for select to authenticated
  using (status <> 'draft' and private.is_active_user());

create policy "programmes: counsellors read all"
  on public.programmes for select to authenticated
  using (private.is_counsellor());

create policy "programmes: counsellors create"
  on public.programmes for insert to authenticated
  with check (private.is_counsellor() and created_by = (select auth.uid()));

create policy "programmes: counsellors update"
  on public.programmes for update to authenticated
  using (private.is_counsellor())
  with check (private.is_counsellor());

create policy "programmes: counsellors delete drafts"
  on public.programmes for delete to authenticated
  using (private.is_counsellor() and status = 'draft');

alter table public.programme_registrations enable row level security;

create policy "registrations: student reads own"
  on public.programme_registrations for select to authenticated
  using (student_id = (select auth.uid()));

create policy "registrations: counsellors read all"
  on public.programme_registrations for select to authenticated
  using (private.is_counsellor());

alter table public.feedback enable row level security;

create policy "feedback: student reads own"
  on public.feedback for select to authenticated
  using (student_id = (select auth.uid()));

-- Students may give feedback once, only for a programme they registered for
-- (and did not cancel) that has already started.
create policy "feedback: registered student submits"
  on public.feedback for insert to authenticated
  with check (
    student_id = (select auth.uid())
    and private.is_student()
    and exists (
      select 1
      from public.programme_registrations g
      join public.programmes p on p.id = g.programme_id
      where g.programme_id = feedback.programme_id
        and g.student_id = (select auth.uid())
        and g.status in ('registered', 'attended')
        and p.starts_at <= now()
    )
  );

-- ---------------------------------------------------------------------------
-- Workflow functions
-- ---------------------------------------------------------------------------
create or replace function public.register_for_programme(p_programme uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_prog public.programmes%rowtype;
  v_taken integer;
  v_existing public.registration_status;
begin
  if not private.is_student() then
    raise exception 'Only students can register for activities.' using errcode = '42501';
  end if;

  -- Lock the programme row so concurrent registrations cannot overfill it.
  select * into v_prog from public.programmes where id = p_programme for update;
  if not found or v_prog.status <> 'published' then
    raise exception 'This activity is not open for registration.';
  end if;
  if v_prog.starts_at <= now() then
    raise exception 'Registration has closed because this activity has started.';
  end if;

  select status into v_existing from public.programme_registrations
  where programme_id = p_programme and student_id = (select auth.uid());
  if v_existing in ('registered', 'attended') then
    raise exception 'You are already registered for this activity.';
  end if;

  if v_prog.capacity is not null then
    select count(*) into v_taken from public.programme_registrations
    where programme_id = p_programme and status = 'registered';
    if v_taken >= v_prog.capacity then
      raise exception 'Sorry, this activity is full.';
    end if;
  end if;

  insert into public.programme_registrations (programme_id, student_id)
  values (p_programme, (select auth.uid()))
  on conflict on constraint programme_registrations_unique
  do update set status = 'registered', registered_at = now(), cancelled_at = null;
end;
$$;

create or replace function public.cancel_programme_registration(p_programme uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.programme_registrations g
     set status = 'cancelled', cancelled_at = now()
    from public.programmes p
   where p.id = g.programme_id
     and g.programme_id = p_programme
     and g.student_id = (select auth.uid())
     and g.status = 'registered'
     and p.starts_at > now()
     and private.is_active_user();
  if not found then
    raise exception 'This registration can no longer be cancelled.';
  end if;
end;
$$;

create or replace function public.mark_attendance(
  p_registration uuid,
  p_status public.registration_status
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_counsellor() then
    raise exception 'Only counsellors can record attendance.' using errcode = '42501';
  end if;
  if p_status not in ('attended', 'absent') then
    raise exception 'Attendance must be attended or absent.';
  end if;
  update public.programme_registrations g
     set status = p_status, attendance_marked_at = now()
    from public.programmes p
   where p.id = g.programme_id
     and g.id = p_registration
     and g.status in ('registered', 'attended', 'absent')
     and p.starts_at <= now();
  if not found then
    raise exception 'Attendance can be recorded once the activity has started.';
  end if;
end;
$$;

-- Feedback for counsellors: anonymous comments never reveal the student.
create or replace function public.get_programme_feedback(p_programme uuid)
returns table (
  id uuid,
  rating smallint,
  comment text,
  student_name text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.is_counsellor() then
    raise exception 'Only counsellors can review feedback.' using errcode = '42501';
  end if;
  return query
    select f.id, f.rating, f.comment,
           case when f.is_anonymous then null else p.full_name end,
           f.created_at
    from public.feedback f
    left join public.profiles p on p.id = f.student_id
    where f.programme_id = p_programme
    order by f.created_at desc;
end;
$$;

do $$
declare
  fn text;
begin
  foreach fn in array array[
    'public.register_for_programme(uuid)',
    'public.cancel_programme_registration(uuid)',
    'public.mark_attendance(uuid, public.registration_status)',
    'public.get_programme_feedback(uuid)'
  ] loop
    execute format('revoke all on function %s from public, anon', fn);
    execute format('grant execute on function %s to authenticated', fn);
  end loop;
end $$;
