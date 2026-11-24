-- ============================================================================
-- RLS TESTS · part 3 · counsellor self-sign-up (verified email -> role)
-- Run after part 1 and 2 (uses tests.ok / tests.login from part 1).
-- All people below are FICTIONAL. gmi.edu.my addresses are made-up local parts.
-- ============================================================================
\set ON_ERROR_STOP 1
reset role;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-0000000001a1', 'grace.test@gmi.edu.my',
     '{"signup_type":"counsellor","staff_id":"STF001","full_name":"Grace Test"}'),
  ('00000000-0000-4000-8000-0000000002a2', 'hank.test@student.gmi.edu.my',
     '{"signup_type":"counsellor","staff_id":"STF002","full_name":"Hank Test"}'),
  ('00000000-0000-4000-8000-0000000003a3', 'Ivy.Test@GMI.EDU.MY',
     '{"signup_type":"counsellor","staff_id":"stf003","full_name":"Ivy Test"}'),
  ('00000000-0000-4000-8000-0000000004a4', 'jack.test@gmi.edu.my.evil.test',
     '{"signup_type":"counsellor","staff_id":"STF004","full_name":"Jack Test"}'),
  ('00000000-0000-4000-8000-0000000005a5', 'kim.test@gmi.edu.my',
     '{"signup_type":"counsellor","staff_id":"stf001","full_name":"Kim Test"}'),
  ('00000000-0000-4000-8000-0000000006a6', 'lee.test@gmi.edu.my',
     '{"signup_type":"counsellor","staff_id":"a!","full_name":"Lee Test"}'),
  ('00000000-0000-4000-8000-0000000007a7', 'max.test@gmi.edu.my',
     '{"role":"admin","full_name":"Max Test"}'),
  ('00000000-0000-4000-8000-0000000008a8', 'nina.test@gmi.edu.my',
     '{"signup_type":"counsellor","staff_id":"STF008","full_name":"Nina Test"}');

-- Nina is already an administrator before she verifies her email.
update public.user_roles set role = 'admin'
 where user_id = '00000000-0000-4000-8000-0000000008a8';

select tests.ok(
  (select count(*) from public.user_roles
    where user_id in (select id from auth.users where email ilike '%gmi.edu.my%')
      and role = 'student') = 7
  and (select count(*) from public.profiles where staff_id is not null
        and id in (select id from auth.users where email like '%gmi.edu.my%')) = 0,
  'before email confirmation every counsellor sign-up is still a student with no staff id');

-- Confirm every mailbox (what Supabase does after a correct code).
update auth.users set email_confirmed_at = now()
 where email ilike '%gmi.edu.my%';

select tests.ok(
  (select role from public.user_roles where user_id = '00000000-0000-4000-8000-0000000001a1') = 'counsellor'
  and (select staff_id from public.profiles where id = '00000000-0000-4000-8000-0000000001a1') = 'STF001',
  'verified @gmi.edu.my sign-up becomes a counsellor and keeps the staff id');

select tests.ok(
  (select count(*) from public.audit_logs
    where action = 'counsellor_self_registered'
      and target_user_id = '00000000-0000-4000-8000-0000000001a1') = 1,
  'self-registration is written to the audit log');

select tests.ok(
  (select role from public.user_roles where user_id = '00000000-0000-4000-8000-0000000002a2') = 'student'
  and (select details ->> 'reason' from public.audit_logs
        where action = 'counsellor_signup_rejected'
          and target_user_id = '00000000-0000-4000-8000-0000000002a2') = 'domain',
  '@student.gmi.edu.my cannot become a counsellor (rejected, audited)');

select tests.ok(
  (select role from public.user_roles where user_id = '00000000-0000-4000-8000-0000000003a3') = 'counsellor'
  and (select staff_id from public.profiles where id = '00000000-0000-4000-8000-0000000003a3') = 'STF003',
  'domain check is case-insensitive and staff id is stored upper-case');

select tests.ok(
  (select role from public.user_roles where user_id = '00000000-0000-4000-8000-0000000004a4') = 'student',
  'look-alike domain gmi.edu.my.evil.test stays a student');

select tests.ok(
  (select role from public.user_roles where user_id = '00000000-0000-4000-8000-0000000005a5') = 'student'
  and (select details ->> 'reason' from public.audit_logs
        where action = 'counsellor_signup_rejected'
          and target_user_id = '00000000-0000-4000-8000-0000000005a5') = 'staff_id_taken',
  'a staff id already in use (any letter case) is not promoted');

select tests.ok(
  (select role from public.user_roles where user_id = '00000000-0000-4000-8000-0000000006a6') = 'student'
  and (select details ->> 'reason' from public.audit_logs
        where action = 'counsellor_signup_rejected'
          and target_user_id = '00000000-0000-4000-8000-0000000006a6') = 'staff_id_invalid',
  'an invalid staff id is not promoted');

select tests.ok(
  (select role from public.user_roles where user_id = '00000000-0000-4000-8000-0000000007a7') = 'student',
  'a "role":"admin" in sign-up metadata still grants nothing, even with a gmi.edu.my email');

select tests.ok(
  (select role from public.user_roles where user_id = '00000000-0000-4000-8000-0000000008a8') = 'admin',
  'verifying a counsellor sign-up never demotes an existing administrator');

-- A counsellor cannot edit their own staff id.
set role authenticated;
select tests.login('00000000-0000-4000-8000-0000000001a1');
do $$
begin
  begin
    update public.profiles set staff_id = 'HACK1' where id = (select auth.uid());
    raise exception 'FAIL: counsellor changed their own staff id';
  exception when insufficient_privilege then
    raise notice 'PASS: users cannot edit their own staff id';
  end;
end $$;
reset role;
