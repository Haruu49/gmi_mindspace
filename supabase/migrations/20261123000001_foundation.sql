-- ============================================================================
-- GMI MindSpace · 001 · Foundation
-- Extensions, private schema for privileged helpers, enum types and the
-- shared updated_at trigger.
-- ============================================================================

create schema if not exists extensions;
-- btree_gist lets an exclusion constraint combine "same counsellor" (=) with
-- "overlapping time" (&&) to make double booking impossible.
create extension if not exists btree_gist with schema extensions;

-- Privileged helper functions live here. This schema is NOT exposed through
-- the Data API, so its functions cannot be called directly by clients.
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Enum types
-- ---------------------------------------------------------------------------
create type public.app_role as enum ('student', 'counsellor', 'admin');

create type public.mood_type as enum
  ('very_happy', 'good', 'neutral', 'sad', 'stressed');

create type public.mood_reason as enum
  ('academic_pressure', 'family', 'relationships', 'financial',
   'personal', 'health', 'other');

create type public.appointment_type as enum
  ('individual_counselling', 'academic_support',
   'emotional_wellbeing', 'other_support');

create type public.appointment_status as enum
  ('pending', 'confirmed', 'rejected', 'cancelled', 'completed');

create type public.resource_category as enum
  ('understanding_mental_health', 'anxiety_awareness', 'stress_management',
   'depression_awareness', 'self_esteem', 'emotional_intelligence',
   'healthy_relationships', 'academic_burnout', 'sleep_wellbeing',
   'help_seeking');

create type public.resource_format as enum
  ('article', 'infographic', 'video', 'faq', 'download');

create type public.programme_mode as enum ('online', 'physical', 'hybrid');

create type public.programme_status as enum
  ('draft', 'published', 'cancelled', 'completed');

create type public.registration_status as enum
  ('registered', 'cancelled', 'attended', 'absent');

create type public.notification_type as enum
  ('appointment_confirmed', 'appointment_rescheduled', 'appointment_reminder',
   'appointment_update', 'programme_registration', 'programme_upcoming',
   'new_resource', 'general');

-- ---------------------------------------------------------------------------
-- Shared trigger: keep updated_at accurate on every UPDATE.
-- ---------------------------------------------------------------------------
create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
