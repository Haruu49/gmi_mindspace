-- ============================================================================
-- GMI MindSpace · 005 · Counselling workflow functions
--
-- Clients have no direct INSERT/UPDATE on appointments. Every change goes
-- through one of these functions, which:
--   * identify the caller only via auth.uid() (never a passed-in user id),
--   * check the caller's role and ownership / assignment,
--   * allow only valid status transitions.
-- They are SECURITY DEFINER because they write rows the caller cannot write
-- directly; EXECUTE is revoked from anon and PUBLIC.
-- Double booking is still prevented by the exclusion constraints in 004 –
-- a race between two requests fails with SQLSTATE 23P01.
-- ============================================================================

-- Open slots: active, in the future, not held by a live appointment.
-- Returns no student information.
create or replace function public.get_open_slots(p_from date default current_date, p_days integer default 30)
returns table (
  availability_id uuid,
  counsellor_id uuid,
  counsellor_name text,
  starts_at timestamptz,
  ends_at timestamptz,
  location text
)
language sql
stable
security definer
set search_path = ''
as $$
  select s.id, s.counsellor_id, p.full_name, s.starts_at, s.ends_at, s.location
  from public.counsellor_availability s
  join public.profiles p on p.id = s.counsellor_id and p.is_active
  join public.user_roles r on r.user_id = s.counsellor_id and r.role = 'counsellor'
  where private.is_active_user()
    and s.is_active
    and s.starts_at > now()
    and s.starts_at >= p_from::timestamptz
    and s.starts_at < (p_from + least(greatest(p_days, 1), 90))::timestamptz
    and not exists (
      select 1 from public.appointments a
      where a.counsellor_id = s.counsellor_id
        and a.status in ('pending', 'confirmed')
        and tstzrange(a.starts_at, a.ends_at, '[)') && tstzrange(s.starts_at, s.ends_at, '[)')
    )
  order by s.starts_at
$$;

create or replace function public.request_appointment(
  p_availability_id uuid,
  p_type public.appointment_type,
  p_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_slot public.counsellor_availability%rowtype;
  v_id uuid;
begin
  if not private.is_student() then
    raise exception 'Only students can request appointments.' using errcode = '42501';
  end if;
  if p_reason is not null and char_length(p_reason) > 500 then
    raise exception 'Please keep your note under 500 characters.';
  end if;

  select * into v_slot from public.counsellor_availability
  where id = p_availability_id and is_active;
  if not found then
    raise exception 'That slot is no longer available.';
  end if;
  if v_slot.starts_at <= now() then
    raise exception 'That slot has already started. Please pick a future time.';
  end if;
  if not private.is_counsellor_account(v_slot.counsellor_id) then
    raise exception 'That counsellor is not currently available.';
  end if;

  insert into public.appointments
    (student_id, counsellor_id, availability_id, appointment_type,
     starts_at, ends_at, student_reason)
  values
    ((select auth.uid()), v_slot.counsellor_id, v_slot.id, p_type,
     v_slot.starts_at, v_slot.ends_at, nullif(btrim(p_reason), ''))
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.cancel_my_appointment(p_id uuid, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_active_user() then
    raise exception 'Please sign in again.' using errcode = '42501';
  end if;
  update public.appointments
     set status = 'cancelled',
         status_reason = left(nullif(btrim(p_reason), ''), 300),
         reschedule_requested = false
   where id = p_id
     and student_id = (select auth.uid())
     and status in ('pending', 'confirmed')
     and starts_at > now();
  if not found then
    raise exception 'This appointment can no longer be cancelled.';
  end if;
end;
$$;

create or replace function public.request_reschedule(p_id uuid, p_note text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_note is null or char_length(btrim(p_note)) < 5 or char_length(p_note) > 300 then
    raise exception 'Please tell the counsellor which times suit you (5–300 characters).';
  end if;
  update public.appointments
     set reschedule_requested = true,
         reschedule_note = btrim(p_note)
   where id = p_id
     and student_id = (select auth.uid())
     and status in ('pending', 'confirmed')
     and starts_at > now()
     and private.is_active_user();
  if not found then
    raise exception 'This appointment can no longer be rescheduled.';
  end if;
end;
$$;

-- Allowed counsellor transitions:
--   pending   -> confirmed | rejected (reason required) | cancelled (reason)
--   confirmed -> completed (after start) | cancelled (reason)
create or replace function public.counsellor_set_appointment_status(
  p_id uuid,
  p_status public.appointment_status,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_appt public.appointments%rowtype;
  v_reason text := nullif(btrim(p_reason), '');
begin
  if not private.is_counsellor() then
    raise exception 'Only counsellors can update appointments.' using errcode = '42501';
  end if;

  select * into v_appt from public.appointments
  where id = p_id and counsellor_id = (select auth.uid())
  for update;
  if not found then
    raise exception 'Appointment not found or not assigned to you.' using errcode = '42501';
  end if;

  if not (
    (v_appt.status = 'pending' and p_status in ('confirmed', 'rejected', 'cancelled')) or
    (v_appt.status = 'confirmed' and p_status in ('completed', 'cancelled'))
  ) then
    raise exception 'Cannot change an appointment from % to %.', v_appt.status, p_status;
  end if;

  if p_status in ('rejected', 'cancelled') and char_length(coalesce(v_reason, '')) < 5 then
    raise exception 'Please give the student a short explanation (at least 5 characters).';
  end if;
  if p_status = 'completed' and v_appt.starts_at > now() then
    raise exception 'An appointment can only be completed after it has started.';
  end if;

  update public.appointments
     set status = p_status,
         status_reason = case when p_status in ('rejected', 'cancelled')
                              then left(v_reason, 300) else status_reason end,
         reschedule_requested = case when p_status = 'confirmed'
                                     then reschedule_requested else false end
   where id = p_id;
end;
$$;

-- Move an appointment to another open slot of the same counsellor.
create or replace function public.counsellor_reschedule_appointment(
  p_id uuid,
  p_new_availability_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_appt public.appointments%rowtype;
  v_slot public.counsellor_availability%rowtype;
begin
  if not private.is_counsellor() then
    raise exception 'Only counsellors can reschedule appointments.' using errcode = '42501';
  end if;

  select * into v_appt from public.appointments
  where id = p_id and counsellor_id = (select auth.uid())
  for update;
  if not found then
    raise exception 'Appointment not found or not assigned to you.' using errcode = '42501';
  end if;
  if v_appt.status not in ('pending', 'confirmed') then
    raise exception 'Only pending or confirmed appointments can be rescheduled.';
  end if;

  select * into v_slot from public.counsellor_availability
  where id = p_new_availability_id
    and counsellor_id = (select auth.uid())
    and is_active
    and starts_at > now();
  if not found then
    raise exception 'Please choose one of your own future slots.';
  end if;

  -- The exclusion constraint rejects the update if the new slot is taken.
  update public.appointments
     set starts_at = v_slot.starts_at,
         ends_at = v_slot.ends_at,
         availability_id = v_slot.id,
         status = 'confirmed',
         reschedule_requested = false,
         reschedule_note = null,
         reminder_sent_at = null
   where id = p_id;
end;
$$;

do $$
declare
  fn text;
begin
  foreach fn in array array[
    'public.get_open_slots(date, integer)',
    'public.request_appointment(uuid, public.appointment_type, text)',
    'public.cancel_my_appointment(uuid, text)',
    'public.request_reschedule(uuid, text)',
    'public.counsellor_set_appointment_status(uuid, public.appointment_status, text)',
    'public.counsellor_reschedule_appointment(uuid, uuid)'
  ] loop
    execute format('revoke all on function %s from public, anon', fn);
    execute format('grant execute on function %s to authenticated', fn);
  end loop;
end $$;
