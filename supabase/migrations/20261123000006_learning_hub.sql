-- ============================================================================
-- GMI MindSpace · 006 · Mental Health Learning Hub
-- ============================================================================

-- Content permission managed by administrators (see admin_set_content_permission
-- in migration 008). Counsellors can manage content by default.
alter table public.user_roles
  add column can_manage_content boolean not null default true;

create or replace function private.can_manage_content()
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.user_roles r
    join public.profiles p on p.id = r.user_id and p.is_active
    where r.user_id = (select auth.uid())
      and ((r.role = 'counsellor' and r.can_manage_content) or r.role = 'admin')
  )
$$;
revoke all on function private.can_manage_content() from public;
grant execute on function private.can_manage_content() to authenticated;

create table public.resources (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(btrim(title)) between 3 and 150),
  description text not null check (char_length(btrim(description)) between 10 and 300),
  category public.resource_category not null,
  format public.resource_format not null default 'article',
  content text check (content is null or char_length(content) <= 20000),
  image_url text check (image_url is null or char_length(image_url) <= 500),
  media_url text check (media_url is null or media_url ~ '^https://'),
  read_minutes smallint check (read_minutes is null or read_minutes between 1 and 120),
  author_id uuid default auth.uid() references auth.users (id) on delete set null,
  published boolean not null default false,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (format in ('video', 'download') or char_length(coalesce(content, '')) >= 20),
  check (format not in ('video', 'download') or media_url is not null)
);

create index resources_published_idx on public.resources (published, category, published_at desc);

create trigger resources_set_updated_at
  before update on public.resources
  for each row execute function private.set_updated_at();

-- Stamp published_at the first time a resource is published.
create or replace function private.stamp_published_at()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if new.published and (tg_op = 'INSERT' or not old.published) then
    new.published_at := now();
  end if;
  return new;
end;
$$;

create trigger resources_stamp_published
  before insert or update of published on public.resources
  for each row execute function private.stamp_published_at();

create table public.resource_bookmarks (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  resource_id uuid not null references public.resources (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, resource_id)
);

create table public.resource_views (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  resource_id uuid not null references public.resources (id) on delete cascade,
  viewed_at timestamptz not null default now(),
  primary key (user_id, resource_id)
);
create index resource_views_recent_idx on public.resource_views (user_id, viewed_at desc);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.resources enable row level security;

create policy "resources: active users read published"
  on public.resources for select to authenticated
  using (published and private.is_active_user());

create policy "resources: content managers read all"
  on public.resources for select to authenticated
  using (private.can_manage_content());

create policy "resources: content managers insert"
  on public.resources for insert to authenticated
  with check (private.can_manage_content() and author_id = (select auth.uid()));

create policy "resources: content managers update"
  on public.resources for update to authenticated
  using (private.can_manage_content())
  with check (private.can_manage_content());

create policy "resources: content managers delete"
  on public.resources for delete to authenticated
  using (private.can_manage_content());

alter table public.resource_bookmarks enable row level security;

create policy "bookmarks: owner reads"
  on public.resource_bookmarks for select to authenticated
  using (user_id = (select auth.uid()));
create policy "bookmarks: owner adds"
  on public.resource_bookmarks for insert to authenticated
  with check (user_id = (select auth.uid()) and private.is_active_user());
create policy "bookmarks: owner removes"
  on public.resource_bookmarks for delete to authenticated
  using (user_id = (select auth.uid()));

alter table public.resource_views enable row level security;

create policy "views: owner reads"
  on public.resource_views for select to authenticated
  using (user_id = (select auth.uid()));
create policy "views: owner records"
  on public.resource_views for insert to authenticated
  with check (user_id = (select auth.uid()) and private.is_active_user());
create policy "views: owner refreshes"
  on public.resource_views for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy "views: owner clears"
  on public.resource_views for delete to authenticated
  using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- Storage: approved learning / programme images.
-- Public read (images accompany published content); only content managers
-- may upload, replace or delete. 5 MB, images only.
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('learning-media', 'learning-media', true, 5242880,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy "learning-media: managers upload"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'learning-media' and private.can_manage_content());

create policy "learning-media: managers read"
  on storage.objects for select to authenticated
  using (bucket_id = 'learning-media' and private.can_manage_content());

create policy "learning-media: managers replace"
  on storage.objects for update to authenticated
  using (bucket_id = 'learning-media' and private.can_manage_content())
  with check (bucket_id = 'learning-media' and private.can_manage_content());

create policy "learning-media: managers delete"
  on storage.objects for delete to authenticated
  using (bucket_id = 'learning-media' and private.can_manage_content());
