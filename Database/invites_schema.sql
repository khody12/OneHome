-- pending_invites table
-- Add this to your Supabase instance after schema.sql

create table public.pending_invites (
  id uuid primary key default gen_random_uuid(),
  home_id uuid references public.homes(id) on delete cascade,
  invitee_id uuid references public.users(id) on delete cascade,
  inviter_id uuid references public.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz default now(),
  unique(home_id, invitee_id, status)  -- prevent duplicate pending invites
);

alter table public.pending_invites enable row level security;

create policy "Invitees can see their own invites"
  on public.pending_invites for select
  using (auth.uid() = invitee_id);

create policy "Home owners can send invites"
  on public.pending_invites for insert
  with check (
    auth.uid() = inviter_id and
    exists (select 1 from public.homes where id = home_id and owner_id = auth.uid())
  );

create policy "Invitees can update status (accept/decline)"
  on public.pending_invites for update
  using (auth.uid() = invitee_id);
