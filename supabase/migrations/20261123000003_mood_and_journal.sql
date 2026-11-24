-- ============================================================================
-- GMI MindSpace · 003 · Mood check-ins, journal and mood-sharing consent
--
-- PRIVACY MODEL
--  * mood_entries and journal_entries are visible ONLY to their owner.
--    There is deliberately no policy for counsellors or administrators.
--  * A student may opt in to share an aggregated mood summary (counts per
--    mood only – never notes or reasons) with one named counsellor, for a
--    limited time, and can revoke it at any moment.
-- ============================================================================

create table public.mood_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  mood public.mood_type not null,
  reason public.mood_reason,
  notes text check (notes is null or char_length(notes) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index mood_entries_user_created_idx
  on public.mood_entries (user_id, created_at desc);

create trigger mood_entries_set_updated_at
  before update on public.mood_entries
  for each row execute function private.set_updated_at();

create table public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 120),
  content text not null check (char_length(btrim(content)) between 1 and 10000),
  entry_date date not null default current_date,
  prompt text check (prompt is null or char_length(prompt) <= 200),
  is_gratitude boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index journal_entries_user_date_idx
  on public.journal_entries (user_id, entry_date desc, created_at desc);

create trigger journal_entries_set_updated_at
  before update on public.journal_entries
  for each row execute function private.set_updated_at();

-- ---------------------------------------------------------------------------
-- RLS: owner-only, every operation. Active-account check blocks
-- deactivated users even if they still hold a valid token.
-- ---------------------------------------------------------------------------
alter table public.mood_entries enable row level security;

create policy "mood: owner reads"
  on public.mood_entries for select to authenticated
  using (user_id = (select auth.uid()) and private.is_active_user());

create policy "mood: owner inserts"
  on public.mood_entries for insert to authenticated
  with check (user_id = (select auth.uid()) and private.is_active_user());

create policy "mood: owner updates"
  on public.mood_entries for update to authenticated
  using (user_id = (select auth.uid()) and private.is_active_user())
  with check (user_id = (select auth.uid()));

create policy "mood: owner deletes"
  on public.mood_entries for delete to authenticated
  using (user_id = (select auth.uid()) and private.is_active_user());

alter table public.journal_entries enable row level security;

create policy "journal: owner reads"
  on public.journal_entries for select to authenticated
  using (user_id = (select auth.uid()) and private.is_active_user());

create policy "journal: owner inserts"
  on public.journal_entries for insert to authenticated
  with check (user_id = (select auth.uid()) and private.is_active_user());

create policy "journal: owner updates"
  on public.journal_entries for update to authenticated
  using (user_id = (select auth.uid()) and private.is_active_user())
  with check (user_id = (select auth.uid()));

create policy "journal: owner deletes"
  on public.journal_entries for delete to authenticated
  using (user_id = (select auth.uid()) and private.is_active_user());

-- ---------------------------------------------------------------------------
-- Explicit, revocable, time-limited consent to share a mood SUMMARY.
-- ---------------------------------------------------------------------------
create table public.mood_share_consents (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  counsellor_id uuid not null references auth.users (id) on delete cascade,
  period_days integer not null default 30 check (period_days in (7, 14, 30)),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '30 days'),
  revoked_at timestamptz,
  check (student_id <> counsellor_id),
  check (expires_at > created_at)
);

create index mood_share_consents_student_idx
  on public.mood_share_consents (student_id, created_at desc);
create index mood_share_consents_counsellor_idx
  on public.mood_share_consents (counsellor_id) where revoked_at is null;

alter table public.mood_share_consents enable row level security;

create policy "consent: student reads own"
  on public.mood_share_consents for select to authenticated
  using (student_id = (select auth.uid()));

create policy "consent: student grants to a counsellor"
  on public.mood_share_consents for insert to authenticated
  with check (
    student_id = (select auth.uid())
    and private.is_student()
    and private.is_counsellor_account(counsellor_id)
    and revoked_at is null
  );

-- Students may only set revoked_at (column grant in migration 009).
create policy "consent: student revokes own"
  on public.mood_share_consents for update to authenticated
  using (student_id = (select auth.uid()))
  with check (student_id = (select auth.uid()));

create policy "consent: counsellor sees consents granted to them"
  on public.mood_share_consents for select to authenticated
  using (counsellor_id = (select auth.uid()) and private.is_counsellor());

-- ---------------------------------------------------------------------------
-- Counsellor-facing summary. Returns ONLY counts per mood for the consented
-- period, and only while consent is active. Notes and reasons never leave
-- the table.
-- ---------------------------------------------------------------------------
create or replace function public.get_shared_mood_summary(p_student uuid)
returns table (mood public.mood_type, total bigint, period_days integer)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_days integer;
begin
  if not private.is_counsellor() then
    raise exception 'Only counsellors can view shared summaries.'
      using errcode = '42501';
  end if;

  select c.period_days into v_days
  from public.mood_share_consents c
  where c.student_id = p_student
    and c.counsellor_id = (select auth.uid())
    and c.revoked_at is null
    and c.expires_at > now()
  order by c.created_at desc
  limit 1;

  if v_days is null then
    raise exception 'This student has not shared a mood summary with you.'
      using errcode = '42501';
  end if;

  return query
    select m.mood, count(*)::bigint, v_days
    from public.mood_entries m
    where m.user_id = p_student
      and m.created_at >= now() - make_interval(days => v_days)
    group by m.mood;
end;
$$;

revoke all on function public.get_shared_mood_summary(uuid) from public, anon;
grant execute on function public.get_shared_mood_summary(uuid) to authenticated;
