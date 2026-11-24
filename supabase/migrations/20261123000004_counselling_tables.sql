-- ============================================================================
-- GMI MindSpace · 004 · Counselling: availability, appointments, private notes
-- ============================================================================

create table public.counsellor_availability (
  id uuid primary key default gen_random_uuid(),
  counsellor_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  location text check (location is null or char_length(location) <= 120),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at),
  check (ends_at - starts_at between interval '15 minutes' and interval '4 hours'),
  -- A counsellor cannot publish two overlapping active slots.
  constraint counsellor_availability_no_overlap
    exclude using gist (
      counsellor_id with =,
      tstzrange(starts_at, ends_at, '[)') with &&
    ) where (is_active)
);

create index counsellor_availability_starts_idx
  on public.counsellor_availability (starts_at) where is_active;

create trigger counsellor_availability_set_updated_at
  before update on public.counsellor_availability
  for each row execute function private.set_updated_at();

create table public.appointments (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references auth.users (id) on delete cascade,
  -- RESTRICT: deactivate counsellors instead of deleting them so the
  -- counselling unit keeps its booking history.
  counsellor_id uuid not null references auth.users (id) on delete restrict,
  availability_id uuid references public.counsellor_availability (id)
    on delete set null,
  appointment_type public.appointment_type not null,
  status public.appointment_status not null default 'pending',
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  -- Optional short note from the student. Shown only on the detail screen
  -- to the student and the assigned counsellor; excluded from list views.
  student_reason text check (student_reason is null or char_length(student_reason) <= 500),
  status_reason text check (status_reason is null or char_length(status_reason) <= 300),
  reschedule_requested boolean not null default false,
  reschedule_note text check (reschedule_note is null or char_length(reschedule_note) <= 300),
  reminder_sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at),
  check (student_id <> counsellor_id),
  check (status <> 'rejected' or char_length(coalesce(status_reason, '')) >= 5),
  -- DOUBLE-BOOKING GUARD: a counsellor can never hold two live (pending or
  -- confirmed) appointments that overlap in time. Enforced atomically by
  -- Postgres, so two students racing for one slot cannot both succeed.
  constraint appointments_no_counsellor_double_booking
    exclude using gist (
      counsellor_id with =,
      tstzrange(starts_at, ends_at, '[)') with &&
    ) where (status in ('pending', 'confirmed')),
  -- A student cannot hold two overlapping live appointments either.
  constraint appointments_no_student_overlap
    exclude using gist (
      student_id with =,
      tstzrange(starts_at, ends_at, '[)') with &&
    ) where (status in ('pending', 'confirmed'))
);

create index appointments_student_idx on public.appointments (student_id, starts_at desc);
create index appointments_counsellor_idx on public.appointments (counsellor_id, starts_at);
create index appointments_status_idx on public.appointments (status, starts_at);
create index appointments_availability_idx on public.appointments (availability_id);

create trigger appointments_set_updated_at
  before update on public.appointments
  for each row execute function private.set_updated_at();

-- Counsellor's private session notes. Never visible to students or admins
-- and never included in list queries.
create table public.appointment_notes (
  id uuid primary key default gen_random_uuid(),
  appointment_id uuid not null references public.appointments (id) on delete cascade,
  counsellor_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  note text not null check (char_length(btrim(note)) between 1 and 4000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index appointment_notes_appointment_idx on public.appointment_notes (appointment_id);

create trigger appointment_notes_set_updated_at
  before update on public.appointment_notes
  for each row execute function private.set_updated_at();

-- Non-sensitive list view (no student_reason, no notes). security_invoker
-- makes the caller's RLS apply, so the view never widens access.
create view public.appointment_list
with (security_invoker = true) as
  select a.id, a.student_id, a.counsellor_id, a.appointment_type, a.status,
         a.starts_at, a.ends_at, a.reschedule_requested, a.created_at,
         a.updated_at,
         sp.full_name as student_name,
         cp.full_name as counsellor_name
  from public.appointments a
  left join public.profiles sp on sp.id = a.student_id
  left join public.profiles cp on cp.id = a.counsellor_id;

-- Does the calling counsellor have a booking relationship with `target`?
create or replace function private.counsellor_has_student(target uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.appointments a
    where a.student_id = target and a.counsellor_id = (select auth.uid())
  )
$$;
revoke all on function private.counsellor_has_student(uuid) from public;
grant execute on function private.counsellor_has_student(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- RLS
-- Writes to appointments happen only through the workflow functions in
-- migration 005, which validate ownership and allowed status transitions.
-- ---------------------------------------------------------------------------
alter table public.counsellor_availability enable row level security;

create policy "availability: counsellor manages own (read)"
  on public.counsellor_availability for select to authenticated
  using (counsellor_id = (select auth.uid()) and private.is_counsellor());

create policy "availability: counsellor manages own (insert)"
  on public.counsellor_availability for insert to authenticated
  with check (counsellor_id = (select auth.uid()) and private.is_counsellor());

create policy "availability: counsellor manages own (update)"
  on public.counsellor_availability for update to authenticated
  using (counsellor_id = (select auth.uid()) and private.is_counsellor())
  with check (counsellor_id = (select auth.uid()));

create policy "availability: counsellor manages own (delete)"
  on public.counsellor_availability for delete to authenticated
  using (counsellor_id = (select auth.uid()) and private.is_counsellor());

alter table public.appointments enable row level security;

create policy "appointments: student reads own"
  on public.appointments for select to authenticated
  using (student_id = (select auth.uid()) and private.is_active_user());

create policy "appointments: assigned counsellor reads"
  on public.appointments for select to authenticated
  using (counsellor_id = (select auth.uid()) and private.is_counsellor());

alter table public.appointment_notes enable row level security;

create policy "notes: assigned counsellor reads own notes"
  on public.appointment_notes for select to authenticated
  using (
    counsellor_id = (select auth.uid()) and private.is_counsellor()
    and exists (select 1 from public.appointments a
                where a.id = appointment_id and a.counsellor_id = (select auth.uid()))
  );

create policy "notes: assigned counsellor writes"
  on public.appointment_notes for insert to authenticated
  with check (
    counsellor_id = (select auth.uid()) and private.is_counsellor()
    and exists (select 1 from public.appointments a
                where a.id = appointment_id and a.counsellor_id = (select auth.uid()))
  );

create policy "notes: author updates"
  on public.appointment_notes for update to authenticated
  using (counsellor_id = (select auth.uid()) and private.is_counsellor())
  with check (counsellor_id = (select auth.uid()));

create policy "notes: author deletes"
  on public.appointment_notes for delete to authenticated
  using (counsellor_id = (select auth.uid()) and private.is_counsellor());

-- Counsellors may see the basic profile of students they have appointments
-- with (name / student ID). Profiles contain no mood or journal content.
create policy "profiles: counsellor reads own clients"
  on public.profiles for select to authenticated
  using (private.is_counsellor() and private.counsellor_has_student(id));
