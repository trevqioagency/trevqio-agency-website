-- Run once in Supabase Dashboard > SQL Editor (after supabase-site-settings.sql).
-- Homepage photos & videos: public can READ, only the main admin and assigned team admins can change.

create table if not exists public.site_media (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('image','video','embed')),
  url text not null,
  storage_path text,
  title text,
  caption text,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

alter table public.site_media enable row level security;

-- Who counts as an admin: your main account, or anyone listed in team_admins.
create or replace function public.is_site_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select (auth.jwt() ->> 'email') = 'trevqioagency@gmail.com'
      or exists (select 1 from public.team_admins where uid = auth.uid());
$$;

drop policy if exists "site_media public read" on public.site_media;
create policy "site_media public read" on public.site_media for select using (true);

drop policy if exists "site_media admin insert" on public.site_media;
create policy "site_media admin insert" on public.site_media for insert with check (public.is_site_admin());

drop policy if exists "site_media admin update" on public.site_media;
create policy "site_media admin update" on public.site_media for update using (public.is_site_admin()) with check (public.is_site_admin());

drop policy if exists "site_media admin delete" on public.site_media;
create policy "site_media admin delete" on public.site_media for delete using (public.is_site_admin());

-- Storage bucket for the uploaded files (public so the homepage can show them; 50 MB per file).
insert into storage.buckets (id, name, public, file_size_limit)
values ('site-media', 'site-media', true, 52428800)
on conflict (id) do update set public = true, file_size_limit = 52428800;

drop policy if exists "site-media public read" on storage.objects;
create policy "site-media public read" on storage.objects for select using (bucket_id = 'site-media');

drop policy if exists "site-media admin upload" on storage.objects;
create policy "site-media admin upload" on storage.objects for insert with check (bucket_id = 'site-media' and public.is_site_admin());

drop policy if exists "site-media admin delete" on storage.objects;
create policy "site-media admin delete" on storage.objects for delete using (bucket_id = 'site-media' and public.is_site_admin());
