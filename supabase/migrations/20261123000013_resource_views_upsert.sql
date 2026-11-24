-- ============================================================================
-- GMI MindSpace · 013 · Allow "recently viewed" upserts
-- PostgREST upsert (INSERT … ON CONFLICT DO UPDATE) sets every supplied
-- column, including resource_id. Rows stay owner-only via RLS.
-- ============================================================================
grant update (resource_id, viewed_at) on public.resource_views to authenticated;
