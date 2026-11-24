-- ============================================================================
-- GMI MindSpace · 015 · Counsellor self-sign-up (verified email -> role)
--
-- A counsellor signs up in the app with full name, Staff ID and a
-- @gmi.edu.my email. Supabase e-mails a 6-digit code; when it is accepted,
-- auth.users.email_confirmed_at is set and THIS trigger grants the counsellor
-- role. The client can never choose a role: the grant needs (1) a confirmed
-- mailbox, (2) the exact domain gmi.edu.my, (3) a valid, unused Staff ID.
-- Sign-up metadata only expresses intent ("signup_type") and the Staff ID.
-- ============================================================================

alter table public.profiles
  add column staff_id text
    check (staff_id is null or staff_id ~ '^[A-Za-z0-9]{3,20}$');

create unique index profiles_staff_id_key
  on public.profiles (upper(staff_id)) where staff_id is not null;

-- staff_id is deliberately NOT in the UPDATE column grant (migration 010):
-- users cannot edit it.

create or replace function private.promote_verified_counsellor()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_staff  text := upper(btrim(coalesce(new.raw_user_meta_data ->> 'staff_id', '')));
  v_reason text;
begin
  -- Only people who asked to be counsellors, and only plain students
  -- (an administrator is never changed by this path).
  if coalesce(new.raw_user_meta_data ->> 'signup_type', '') <> 'counsellor' then
    return new;
  end if;
  if not exists (
    select 1 from public.user_roles where user_id = new.id and role = 'student'
  ) then
    return new;
  end if;

  if lower(split_part(coalesce(new.email, ''), '@', 2)) <> 'gmi.edu.my' then
    v_reason := 'domain';
  elsif v_staff !~ '^[A-Z0-9]{3,20}$' then
    v_reason := 'staff_id_invalid';
  elsif exists (
    select 1 from public.profiles p
    where upper(p.staff_id) = v_staff and p.id <> new.id
  ) then
    v_reason := 'staff_id_taken';
  end if;

  if v_reason is null then
    begin
      update public.profiles set staff_id = v_staff where id = new.id;
      update public.user_roles set role = 'counsellor' where user_id = new.id;
      perform private.audit('counsellor_self_registered', new.id, '{}'::jsonb);
    exception when unique_violation then
      -- Two people verified the same Staff ID at the same moment.
      v_reason := 'staff_id_taken';
    end;
  end if;

  -- Never raise: the email IS verified, the person just stays a student.
  if v_reason is not null then
    perform private.audit('counsellor_signup_rejected', new.id,
      jsonb_build_object('reason', v_reason));
  end if;
  return new;
end;
$$;

revoke all on function private.promote_verified_counsellor() from public;

create trigger on_auth_user_email_confirmed
  after update of email_confirmed_at on auth.users
  for each row
  when (old.email_confirmed_at is null and new.email_confirmed_at is not null)
  execute function private.promote_verified_counsellor();
