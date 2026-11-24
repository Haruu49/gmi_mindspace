-- ============================================================================
-- RLS TESTS · part 2 · roles, counselling, programmes, resources, admin
-- Requires part 1 to have run in the same database.
-- ============================================================================
\set ON_ERROR_STOP 1

-- Helper: expect any error whose SQLSTATE matches (or any error when null).
create or replace function tests.fails(p_sql text, p_state text, msg text) returns void
language plpgsql as $$
declare failed boolean := false; got text;
begin
  begin
    execute p_sql;
  exception when others then
    got := sqlstate;
    failed := (p_state is null or got = p_state);
  end;
  perform tests.ok(failed, msg || coalesce(' [got ' || got || ']', ' [no error]'));
end $$;
grant execute on function tests.fails(text, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Role escalation attempts by a student
-- ---------------------------------------------------------------------------
set role authenticated;
select tests.login('00000000-0000-4000-8000-0000000000b2');

select tests.fails($$update public.user_roles set role = 'counsellor'$$, '42501',
  'student cannot change their own role directly');
select tests.fails($$insert into public.user_roles (user_id, role) values (auth.uid(), 'admin')$$, '42501',
  'student cannot insert an admin role');
select tests.fails($$select public.admin_set_user_role(auth.uid(), 'counsellor')$$, '42501',
  'student cannot assign themselves a counsellor role via RPC');
select tests.fails($$update public.profiles set is_active = true where id = auth.uid()$$, '42501',
  'student cannot change their own active flag');
select tests.fails($$select public.counsellor_dashboard_stats()$$, '42501',
  'student cannot open counsellor reports');

-- ---------------------------------------------------------------------------
-- Resources: only authorised content managers can publish
-- ---------------------------------------------------------------------------
select tests.fails($$insert into public.resources (title, description, category, content, published)
  values ('Fake', 'Unauthorised article text', 'self_esteem', repeat('x', 40), true)$$, '42501',
  'student cannot publish resources');

select tests.login('00000000-0000-4000-8000-0000000000c3');
insert into public.resources (title, description, category, content, published)
values ('Draft article', 'Work in progress article', 'stress_management', repeat('Breathe. ', 10), false),
       ('Managing exam stress', 'Simple ways to cope during exams', 'stress_management', repeat('Plan breaks. ', 10), true);
select tests.ok((select count(*) from public.resources) = 2, 'counsellor creates and sees draft + published resources');

select tests.login('00000000-0000-4000-8000-0000000000b2');
select tests.ok((select count(*) from public.resources) = 1, 'student sees only published resources');
select tests.ok((select count(*) from public.notifications where type = 'new_resource') = 1,
  'publishing a resource notifies students (generic text)');

-- Admin revokes carol's content permission -> carol can no longer publish.
reset role; set role authenticated;
select tests.login('00000000-0000-4000-8000-0000000000e5');
select public.admin_set_content_permission('00000000-0000-4000-8000-0000000000c3', false);
select tests.login('00000000-0000-4000-8000-0000000000c3');
select tests.fails($$insert into public.resources (title, description, category, content)
  values ('Another', 'Should be blocked now', 'self_esteem', repeat('y', 40))$$, '42501',
  'counsellor without content permission cannot add resources');
select tests.login('00000000-0000-4000-8000-0000000000e5');
select public.admin_set_content_permission('00000000-0000-4000-8000-0000000000c3', true);

-- ---------------------------------------------------------------------------
-- Counselling: ownership, assignment, double booking, transitions
-- ---------------------------------------------------------------------------
select tests.login('00000000-0000-4000-8000-0000000000c3');
insert into public.counsellor_availability (starts_at, ends_at, location)
values (date_trunc('hour', now()) + interval '2 days', date_trunc('hour', now()) + interval '2 days 1 hour', 'Room A'),
       (date_trunc('hour', now()) + interval '3 days', date_trunc('hour', now()) + interval '3 days 1 hour', 'Room A');
select tests.fails($$insert into public.counsellor_availability (starts_at, ends_at)
  values (date_trunc('hour', now()) + interval '2 days 30 minutes', date_trunc('hour', now()) + interval '2 days 90 minutes')$$,
  '23P01', 'counsellor cannot publish overlapping slots');

select tests.login('00000000-0000-4000-8000-0000000000a1');
select tests.ok((select count(*) from public.get_open_slots()) = 2, 'student sees 2 open slots');
select public.request_appointment(
  (select availability_id from public.get_open_slots() order by starts_at limit 1),
  'individual_counselling', 'PRIVATE-REASON feeling overwhelmed');
select tests.ok((select count(*) from public.get_open_slots()) = 1, 'booked slot disappears from open slots');

-- Bob races for the same slot id -> blocked by the exclusion constraint.
select tests.login('00000000-0000-4000-8000-0000000000b2');
select tests.fails($$select public.request_appointment(
  (select id from public.counsellor_availability limit 0), 'academic_support', null)$$, null,
  'requesting a non-visible/nonexistent slot fails');
reset role;
create temp table _slot as
  select availability_id as id from public.appointments limit 1;
grant select on _slot to authenticated;
set role authenticated;
select tests.login('00000000-0000-4000-8000-0000000000b2');
select tests.fails($$select public.request_appointment((select id from _slot), 'academic_support', null)$$,
  '23P01', 'double booking the same counsellor slot is impossible');
select tests.ok((select count(*) from public.appointments) = 0, 'bob cannot see alice''s appointment');
select tests.ok((select count(*) from public.appointment_list) = 0, 'list view respects RLS (security_invoker)');

select tests.login('00000000-0000-4000-8000-0000000000d4');
select tests.ok((select count(*) from public.appointments) = 0, 'unassigned counsellor cannot see the appointment');
reset role;
create temp table _appt as select id from public.appointments limit 1;
grant select on _appt to authenticated;
set role authenticated;
select tests.login('00000000-0000-4000-8000-0000000000d4');
select tests.fails($$select public.counsellor_set_appointment_status((select id from _appt), 'confirmed')$$,
  '42501', 'unassigned counsellor cannot confirm the appointment');

select tests.login('00000000-0000-4000-8000-0000000000a1');
select tests.fails($$update public.appointments set status = 'confirmed'$$, '42501',
  'student cannot change appointment status directly');

select tests.login('00000000-0000-4000-8000-0000000000c3');
select tests.ok((select count(*) from public.appointments) = 1, 'assigned counsellor sees the appointment');
select tests.ok((select student_name from public.appointment_list) = 'Alice Test',
  'assigned counsellor sees the student''s name');
select tests.fails($$select public.counsellor_set_appointment_status((select id from _appt), 'rejected', '')$$,
  'P0001', 'rejecting without an explanation is refused');
select tests.fails($$select public.counsellor_set_appointment_status((select id from _appt), 'completed')$$,
  'P0001', 'pending -> completed is not an allowed transition');
select public.counsellor_set_appointment_status((select id from _appt), 'confirmed');
insert into public.appointment_notes (appointment_id, note)
values ((select id from _appt), 'COUNSELLOR-PRIVATE-NOTE');

select tests.login('00000000-0000-4000-8000-0000000000a1');
select tests.ok((select status from public.appointments) = 'confirmed', 'student sees confirmed status');
select tests.ok((select count(*) from public.notifications where type = 'appointment_confirmed') = 1,
  'student receives a confirmation notification');
select tests.ok((select bool_and(body not ilike '%overwhelmed%' and body not ilike '%Room%')
                 from public.notifications), 'notification text contains no private details');
select tests.ok((select count(*) from public.appointment_notes) = 0, 'student cannot read counsellor notes');
select public.cancel_my_appointment((select id from _appt), 'Feeling better');
select tests.ok((select status from public.appointments) = 'cancelled', 'student can cancel own appointment');

select tests.login('00000000-0000-4000-8000-0000000000e5');
select tests.ok((select count(*) from public.appointments) = 0, 'admin has no access to appointment records');
select tests.ok((select count(*) from public.appointment_notes) = 0, 'admin cannot read counsellor notes');

-- ---------------------------------------------------------------------------
-- Programmes: duplicates, capacity, feedback timing
-- ---------------------------------------------------------------------------
select tests.login('00000000-0000-4000-8000-0000000000c3');
insert into public.programmes (title, description, category, mode, location, starts_at, ends_at, capacity, status)
values ('Mindfulness Workshop', 'A calm one-hour mindfulness session', 'Workshop', 'physical', 'Hall B',
        now() + interval '1 day', now() + interval '1 day 1 hour', 1, 'published');
reset role;
create temp table _prog as select id from public.programmes limit 1;
grant select on _prog to authenticated;
set role authenticated;

select tests.login('00000000-0000-4000-8000-0000000000a1');
select public.register_for_programme((select id from _prog));
select tests.fails($$select public.register_for_programme((select id from _prog))$$, 'P0001',
  'duplicate registration is refused');
select tests.ok((select count(*) from public.notifications where type = 'programme_registration') = 1,
  'registration confirmation notification created');
select tests.fails($$insert into public.feedback (programme_id, rating) values ((select id from _prog), 5)$$,
  '42501', 'feedback before the activity starts is refused');

select tests.login('00000000-0000-4000-8000-0000000000b2');
select tests.fails($$select public.register_for_programme((select id from _prog))$$, 'P0001',
  'registration beyond capacity is refused');
select tests.fails($$insert into public.programmes (title, description, mode, location, starts_at, ends_at)
  values ('x', 'not allowed', 'physical', 'x', now(), now() + interval '1 hour')$$, '42501',
  'student cannot create programmes');

-- ---------------------------------------------------------------------------
-- Administration and audit log
-- ---------------------------------------------------------------------------
select tests.login('00000000-0000-4000-8000-0000000000e5');
select tests.fails($$select public.admin_set_user_role(auth.uid(), 'student')$$, '42501',
  'admin cannot change their own role');
select public.admin_set_user_role('00000000-0000-4000-8000-0000000000b2', 'counsellor');
select public.admin_set_user_role('00000000-0000-4000-8000-0000000000b2', 'student');
select tests.ok((select count(*) from public.audit_logs where action = 'role_changed') = 2,
  'role changes are written to the audit log');
select tests.fails($$insert into public.audit_logs (action) values ('forged')$$, '42501',
  'audit log cannot be forged');
select tests.fails($$delete from public.audit_logs$$, '42501', 'audit log cannot be deleted');
select tests.ok((select count(*) from public.admin_list_users()) = 6, 'admin can list accounts');

select public.admin_set_account_active('00000000-0000-4000-8000-0000000000a1', false);
select tests.login('00000000-0000-4000-8000-0000000000a1');
select tests.ok((select count(*) from public.journal_entries) = 0, 'deactivated account loses data access');
select tests.fails($$insert into public.mood_entries (mood) values ('good')$$, '42501',
  'deactivated account cannot write');

select tests.login('00000000-0000-4000-8000-0000000000b2');
select tests.ok((select count(*) from public.audit_logs) = 0, 'students cannot read the audit log');

select tests.login('00000000-0000-4000-8000-0000000000f6');
select public.admin_set_user_role('00000000-0000-4000-8000-0000000000e5', 'student');
select tests.fails($$select public.admin_set_user_role(auth.uid(), 'student')$$, '42501',
  'the remaining admin cannot demote themselves');
reset role;

-- ---------------------------------------------------------------------------
-- Learning hub "recently viewed" upsert + counsellor directory
-- ---------------------------------------------------------------------------
set role authenticated;
select tests.login('00000000-0000-4000-8000-0000000000b2');
insert into public.resource_views (resource_id, viewed_at)
  select id, now() from public.resources where published limit 1
  on conflict (user_id, resource_id) do update set resource_id = excluded.resource_id, viewed_at = excluded.viewed_at;
insert into public.resource_views (resource_id, viewed_at)
  select id, now() from public.resources where published limit 1
  on conflict (user_id, resource_id) do update set resource_id = excluded.resource_id, viewed_at = excluded.viewed_at;
select tests.ok((select count(*) from public.resource_views) = 1, 'recently-viewed upsert works twice without duplicates');
select tests.ok((select count(*) from public.list_counsellors()) = 2, 'counsellor directory lists only active counsellors');
reset role;
