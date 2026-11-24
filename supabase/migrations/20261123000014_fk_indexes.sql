-- ============================================================================
-- GMI MindSpace · 014 · Covering indexes for foreign keys
-- Flagged by the Supabase performance advisor (unindexed_foreign_keys).
-- Speeds up joins and ON DELETE checks when users are removed.
-- ============================================================================
create index if not exists app_settings_updated_by_idx on public.app_settings (updated_by);
create index if not exists appointment_notes_counsellor_idx on public.appointment_notes (counsellor_id);
create index if not exists audit_logs_actor_idx on public.audit_logs (actor_id);
create index if not exists feedback_student_idx on public.feedback (student_id);
create index if not exists programmes_created_by_idx on public.programmes (created_by);
create index if not exists resource_bookmarks_resource_idx on public.resource_bookmarks (resource_id);
create index if not exists resource_views_resource_idx on public.resource_views (resource_id);
create index if not exists resources_author_idx on public.resources (author_id);
create index if not exists user_roles_assigned_by_idx on public.user_roles (assigned_by);
