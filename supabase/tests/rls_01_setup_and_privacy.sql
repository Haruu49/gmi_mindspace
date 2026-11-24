-- ============================================================================
-- RLS TESTS · part 1 · fictional test accounts + privacy of mood/journal
-- Run order: supabase_shim.sql (local only) -> migrations -> this -> part 2.
-- All people below are FICTIONAL. Never use real student data in tests.
--
--   alice  ...a1  student          bob    ...b2  student
--   carol  ...c3  counsellor       dave   ...d4  counsellor
--   erin   ...e5  admin            frank  ...f6  admin
-- ============================================================================
\set ON_ERROR_STOP 1
set client_min_messages = notice;

create schema if not exists tests;
grant usage on schema tests to anon, authenticated;

create or replace function tests.ok(cond boolean, msg text) returns void
language plpgsql as $$
begin
  if cond is distinct from true then
    raise exception 'FAIL: %', msg;
  end if;
  raise notice 'PASS: %', msg;
end $$;
grant execute on function tests.ok(boolean, text) to anon, authenticated;

-- Switch the "logged in" user exactly the way PostgREST does.
create or replace function tests.login(p_user uuid) returns void
language sql as $$
  select set_config('request.jwt.claims',
                    json_build_object('sub', p_user, 'role', 'authenticated')::text,
                    false);
$$;
grant execute on function tests.login(uuid) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Setup (as postgres / service role)
-- ---------------------------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-0000000000a1', 'alice.test@example.test', '{"full_name":"Alice Test","student_id":"GMI00001"}'),
  ('00000000-0000-4000-8000-0000000000b2', 'bob.test@example.test',   '{"full_name":"Bob Test","student_id":"GMI00002"}'),
  ('00000000-0000-4000-8000-0000000000c3', 'carol.test@example.test', '{"full_name":"Carol Counsellor"}'),
  ('00000000-0000-4000-8000-0000000000d4', 'dave.test@example.test',  '{"full_name":"Dave Counsellor"}'),
  ('00000000-0000-4000-8000-0000000000e5', 'erin.test@example.test',  '{"full_name":"Erin Admin"}'),
  -- Tries to self-assign admin via sign-up metadata: must be ignored.
  ('00000000-0000-4000-8000-0000000000f6', 'frank.test@example.test', '{"full_name":"Frank Admin","role":"admin"}');

select tests.ok(
  (select role from public.user_roles where user_id = '00000000-0000-4000-8000-0000000000f6') = 'student',
  'sign-up metadata "role":"admin" is ignored – new users are always students');

-- Bootstrap staff roles (in production: first admin via SQL editor, then the app).
update public.user_roles set role = 'counsellor'
 where user_id in ('00000000-0000-4000-8000-0000000000c3', '00000000-0000-4000-8000-0000000000d4');
update public.user_roles set role = 'admin'
 where user_id in ('00000000-0000-4000-8000-0000000000e5', '00000000-0000-4000-8000-0000000000f6');

-- ---------------------------------------------------------------------------
-- Alice writes private content
-- ---------------------------------------------------------------------------
set role authenticated;
select tests.login('00000000-0000-4000-8000-0000000000a1');

insert into public.mood_entries (mood, reason, notes)
values ('stressed', 'academic_pressure', 'PRIVATE-MOOD-NOTE exam week');
insert into public.journal_entries (title, content)
values ('My day', 'PRIVATE-JOURNAL-CONTENT nobody else should read this');

select tests.ok((select count(*) from public.journal_entries) = 1, 'alice reads her own journal entry');
select tests.ok((select count(*) from public.mood_entries) = 1, 'alice reads her own mood entry');
select tests.ok((select user_id from public.mood_entries) = '00000000-0000-4000-8000-0000000000a1',
                'user_id is filled from auth.uid(), not from the client');

-- ---------------------------------------------------------------------------
-- Bob (another student)
-- ---------------------------------------------------------------------------
select tests.login('00000000-0000-4000-8000-0000000000b2');
select tests.ok((select count(*) from public.journal_entries) = 0, 'bob cannot read alice''s journal');
select tests.ok((select count(*) from public.mood_entries) = 0, 'bob cannot read alice''s mood records');

do $$
declare n integer;
begin
  update public.journal_entries set content = 'hacked' where true;
  get diagnostics n = row_count;
  perform tests.ok(n = 0, 'bob cannot edit alice''s journal (0 rows)');
  delete from public.mood_entries where true;
  get diagnostics n = row_count;
  perform tests.ok(n = 0, 'bob cannot delete alice''s mood records (0 rows)');
end $$;

do $$
declare denied boolean := false;
begin
  begin
    insert into public.journal_entries (user_id, title, content)
    values ('00000000-0000-4000-8000-0000000000a1', 'spoof', 'spoofed entry for alice');
  exception when insufficient_privilege then denied := true;
  end;
  perform tests.ok(denied, 'bob cannot write a journal entry as alice (user_id not writable)');
end $$;

-- ---------------------------------------------------------------------------
-- Carol (counsellor) and Erin (admin) cannot read private content
-- ---------------------------------------------------------------------------
select tests.login('00000000-0000-4000-8000-0000000000c3');
select tests.ok((select count(*) from public.journal_entries) = 0, 'counsellor cannot read private journal content');
select tests.ok((select count(*) from public.mood_entries) = 0, 'counsellor cannot read private mood notes');

do $$
declare denied boolean := false;
begin
  begin
    perform * from public.get_shared_mood_summary('00000000-0000-4000-8000-0000000000a1');
  exception when insufficient_privilege then denied := true;
  end;
  perform tests.ok(denied, 'counsellor gets no mood summary without the student''s consent');
end $$;

select tests.login('00000000-0000-4000-8000-0000000000e5');
select tests.ok((select count(*) from public.journal_entries) = 0, 'admin cannot read student journals');
select tests.ok((select count(*) from public.mood_entries) = 0, 'admin cannot read student mood records');
select tests.ok((select count(*) from public.mood_share_consents) = 0, 'admin cannot read mood-sharing consents');

-- ---------------------------------------------------------------------------
-- Consent workflow: alice shares a SUMMARY with carol, then revokes it.
-- ---------------------------------------------------------------------------
select tests.login('00000000-0000-4000-8000-0000000000a1');
insert into public.mood_share_consents (counsellor_id, period_days)
values ('00000000-0000-4000-8000-0000000000c3', 30);

select tests.login('00000000-0000-4000-8000-0000000000c3');
select tests.ok(
  (select sum(total) from public.get_shared_mood_summary('00000000-0000-4000-8000-0000000000a1')) = 1,
  'with consent, counsellor sees aggregated counts');
select tests.ok(
  (select count(*) from public.mood_entries) = 0,
  'even with consent, counsellor still cannot read mood rows or notes');

select tests.login('00000000-0000-4000-8000-0000000000d4');
do $$
declare denied boolean := false;
begin
  begin
    perform * from public.get_shared_mood_summary('00000000-0000-4000-8000-0000000000a1');
  exception when insufficient_privilege then denied := true;
  end;
  perform tests.ok(denied, 'consent given to carol does not extend to dave');
end $$;

select tests.login('00000000-0000-4000-8000-0000000000a1');
update public.mood_share_consents set revoked_at = now();

select tests.login('00000000-0000-4000-8000-0000000000c3');
do $$
declare denied boolean := false;
begin
  begin
    perform * from public.get_shared_mood_summary('00000000-0000-4000-8000-0000000000a1');
  exception when insufficient_privilege then denied := true;
  end;
  perform tests.ok(denied, 'after the student revokes consent the summary is no longer available');
end $$;

-- ---------------------------------------------------------------------------
-- Signed-out (anon) access
-- ---------------------------------------------------------------------------
reset role;
set role anon;
select set_config('request.jwt.claims', '', false);
do $$
declare denied boolean := false;
begin
  begin
    perform 1 from public.journal_entries;
  exception when insufficient_privilege then denied := true;
  end;
  perform tests.ok(denied, 'signed-out (anon) users cannot touch journal_entries');
end $$;
reset role;
