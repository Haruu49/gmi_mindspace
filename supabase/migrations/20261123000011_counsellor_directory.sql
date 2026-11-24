-- ============================================================================
-- GMI MindSpace · 011 · Counsellor directory
-- Active users can list active counsellors (id + name only) to choose who to
-- share a mood summary with or to see who runs a slot. No other data.
-- ============================================================================

create or replace function public.list_counsellors()
returns table (id uuid, full_name text)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.full_name
  from public.profiles p
  join public.user_roles r on r.user_id = p.id
  where private.is_active_user()
    and r.role = 'counsellor'
    and p.is_active
  order by p.full_name
$$;

revoke all on function public.list_counsellors() from public, anon;
grant execute on function public.list_counsellors() to authenticated;
