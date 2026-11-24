-- ============================================================================
-- GMI MindSpace · 016 · Learning Hub PDF materials
--
-- Counsellors (content managers) attach one PDF to a Learning Hub resource.
-- Files live in the PRIVATE bucket `learning-files`. A student can read a
-- file only while signed in, active, and only when a PUBLISHED resource
-- points at it; the app opens it through a short-lived signed URL.
-- ============================================================================

alter table public.resources
  add column file_path text
    check (file_path is null or file_path ~ '^resources/[A-Za-z0-9._-]+\.pdf$'),
  add column file_name text
    check (file_name is null or char_length(btrim(file_name)) between 1 and 200),
  add column file_size_bytes integer
    check (file_size_bytes is null or file_size_bytes between 1 and 20971520),
  add constraint resources_file_complete check (
    (file_path is null) = (file_name is null)
    and (file_path is null) = (file_size_bytes is null)
  );

-- A "download" resource may now carry a PDF instead of a link. Replace the
-- old unnamed rule "video/download need media_url" (found by its definition,
-- so this works whatever name PostgreSQL generated for it).
do $$
declare v_name text;
begin
  select conname into v_name
  from pg_constraint
  where conrelid = 'public.resources'::regclass
    and contype = 'c'
    and pg_get_constraintdef(oid) like '%media_url IS NOT NULL%'
    and pg_get_constraintdef(oid) like '%download%';
  if v_name is not null then
    execute format('alter table public.resources drop constraint %I', v_name);
  end if;
end $$;

alter table public.resources
  add constraint resources_link_or_file check (
    (format <> 'video' or media_url is not null)
    and (format <> 'download' or media_url is not null or file_path is not null)
  );

create index resources_file_path_idx
  on public.resources (file_path) where file_path is not null;

-- Content managers write these columns (RLS on resources decides who).
grant insert (file_path, file_name, file_size_bytes) on public.resources to authenticated;
grant update (file_path, file_name, file_size_bytes) on public.resources to authenticated;

-- Private bucket: PDF only, 20 MB.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('learning-files', 'learning-files', false, 20971520, array['application/pdf'])
on conflict (id) do nothing;

create policy "learning-files: managers upload"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'learning-files' and private.can_manage_content());

create policy "learning-files: managers read"
  on storage.objects for select to authenticated
  using (bucket_id = 'learning-files' and private.can_manage_content());

create policy "learning-files: managers replace"
  on storage.objects for update to authenticated
  using (bucket_id = 'learning-files' and private.can_manage_content())
  with check (bucket_id = 'learning-files' and private.can_manage_content());

create policy "learning-files: managers delete"
  on storage.objects for delete to authenticated
  using (bucket_id = 'learning-files' and private.can_manage_content());

-- Students: only files of published resources (the subquery runs with the
-- student's own RLS on resources, which already hides drafts).
create policy "learning-files: active users read published"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'learning-files'
    and private.is_active_user()
    and exists (
      select 1 from public.resources r
      where r.published and r.file_path = storage.objects.name
    )
  );
