-- ============================================================================
-- GMI MindSpace · 012 · Realtime for in-app notifications
-- Realtime postgres_changes honour RLS, so each user only receives events for
-- their own notification rows. Guarded so it is a no-op where the Supabase
-- realtime publication does not exist (e.g. local test Postgres).
-- ============================================================================
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'notifications'
     ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;
