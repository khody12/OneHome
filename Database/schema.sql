-- OneHome Database Schema
-- Run this in your Supabase SQL editor or local Supabase instance

-- Users (auth is handled by Supabase auth.users; this extends it)
create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  name text not null,
  email text not null,
  avatar_url text,
  created_at timestamptz default now()
);

-- Homes
create table public.homes (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner_id uuid references public.users(id) on delete cascade,
  invite_code text unique not null,
  created_at timestamptz default now()
);

-- Home membership
create table public.home_members (
  home_id uuid references public.homes(id) on delete cascade,
  user_id uuid references public.users(id) on delete cascade,
  joined_at timestamptz default now(),
  primary key (home_id, user_id)
);

-- Posts
create table public.posts (
  id uuid primary key default gen_random_uuid(),
  home_id uuid references public.homes(id) on delete cascade,
  user_id uuid references public.users(id) on delete cascade,
  category text not null check (category in ('chore', 'purchase', 'general')),
  text text not null default '',
  image_url text,
  is_draft boolean not null default true,
  kudos_count integer not null default 0,
  created_at timestamptz default now()
);

-- Kudos (one per user per post)
create table public.kudos (
  id uuid primary key default gen_random_uuid(),
  post_id uuid references public.posts(id) on delete cascade,
  user_id uuid references public.users(id) on delete cascade,
  created_at timestamptz default now(),
  unique(post_id, user_id)
);

-- Trigger to keep kudos_count in sync
create or replace function update_kudos_count()
returns trigger language plpgsql as $$
begin
  if tg_op = 'INSERT' then
    update posts set kudos_count = kudos_count + 1 where id = new.post_id;
  elsif tg_op = 'DELETE' then
    update posts set kudos_count = kudos_count - 1 where id = old.post_id;
  end if;
  return null;
end;
$$;

create trigger kudos_count_trigger
after insert or delete on public.kudos
for each row execute function update_kudos_count();

-- Comments
create table public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid references public.posts(id) on delete cascade,
  user_id uuid references public.users(id) on delete cascade,
  text text not null,
  created_at timestamptz default now()
);

-- Sticky notes (ephemeral, expire after 48h)
create table public.sticky_notes (
  id uuid primary key default gen_random_uuid(),
  home_id uuid references public.homes(id) on delete cascade,
  user_id uuid references public.users(id) on delete cascade,
  text text not null,
  created_at timestamptz default now(),
  expires_at timestamptz not null default (now() + interval '48 hours')
);

-- User metrics per home
create table public.user_metrics (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade,
  home_id uuid references public.homes(id) on delete cascade,
  chores_done integer not null default 0,
  total_spent numeric not null default 0,
  last_post_at timestamptz,
  unique(user_id, home_id)
);

-- RPC: increment chores done
create or replace function increment_chores(p_user_id uuid, p_home_id uuid, p_last_post text)
returns void language plpgsql as $$
begin
  insert into public.user_metrics (user_id, home_id, chores_done, last_post_at)
  values (p_user_id, p_home_id, 1, p_last_post::timestamptz)
  on conflict (user_id, home_id) do update
    set chores_done = user_metrics.chores_done + 1,
        last_post_at = p_last_post::timestamptz;
end;
$$;

-- RPC: increment money spent
create or replace function increment_spent(p_user_id uuid, p_home_id uuid, p_amount numeric, p_last_post text)
returns void language plpgsql as $$
begin
  insert into public.user_metrics (user_id, home_id, total_spent, last_post_at)
  values (p_user_id, p_home_id, p_amount, p_last_post::timestamptz)
  on conflict (user_id, home_id) do update
    set total_spent = user_metrics.total_spent + p_amount,
        last_post_at = p_last_post::timestamptz;
end;
$$;

-- RPC: update last post timestamp only
create or replace function update_last_post(p_user_id uuid, p_home_id uuid, p_last_post text)
returns void language plpgsql as $$
begin
  insert into public.user_metrics (user_id, home_id, last_post_at)
  values (p_user_id, p_home_id, p_last_post::timestamptz)
  on conflict (user_id, home_id) do update
    set last_post_at = p_last_post::timestamptz;
end;
$$;

-- Enable Row Level Security on all tables
alter table public.users enable row level security;
alter table public.homes enable row level security;
alter table public.home_members enable row level security;
alter table public.posts enable row level security;
alter table public.kudos enable row level security;
alter table public.comments enable row level security;
alter table public.sticky_notes enable row level security;
alter table public.user_metrics enable row level security;

-- RLS Policies (permissive for now — users can see/edit within homes they belong to)
create policy "Users can read own profile" on public.users for select using (true);
create policy "Users can update own profile" on public.users for update using (auth.uid() = id);
create policy "Users can insert own profile" on public.users for insert with check (auth.uid() = id);

create policy "Members can read homes" on public.homes for select using (
  exists (select 1 from public.home_members where home_id = id and user_id = auth.uid())
);
create policy "Anyone can create homes" on public.homes for insert with check (auth.uid() = owner_id);

create policy "Members can read memberships" on public.home_members for select using (true);
create policy "Anyone can join" on public.home_members for insert with check (auth.uid() = user_id);

create policy "Members can see posts" on public.posts for select using (
  exists (select 1 from public.home_members where home_id = posts.home_id and user_id = auth.uid())
);
create policy "Members can insert posts" on public.posts for insert with check (auth.uid() = user_id);
create policy "Authors can update own posts" on public.posts for update using (auth.uid() = user_id);

create policy "Members can give kudos" on public.kudos for insert with check (auth.uid() = user_id);
create policy "Members can remove kudos" on public.kudos for delete using (auth.uid() = user_id);
create policy "Members can see kudos" on public.kudos for select using (true);

create policy "Members can comment" on public.comments for insert with check (auth.uid() = user_id);
create policy "Members can read comments" on public.comments for select using (true);

create policy "Members can post sticky notes" on public.sticky_notes for insert with check (auth.uid() = user_id);
create policy "Members can read sticky notes" on public.sticky_notes for select using (true);
create policy "Authors can delete own sticky notes" on public.sticky_notes for delete using (auth.uid() = user_id);

create policy "Members can see metrics" on public.user_metrics for select using (true);
create policy "System can upsert metrics" on public.user_metrics for all using (true);
