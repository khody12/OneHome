-- Payment requests and splits schema
-- Run this after the base schema.sql

create table public.payment_requests (
  id uuid primary key default gen_random_uuid(),
  post_id uuid references public.posts(id) on delete cascade,
  home_id uuid references public.homes(id) on delete cascade,
  requestor_id uuid references public.users(id),
  total_amount numeric not null,
  note text not null default '',
  created_at timestamptz default now()
);

create table public.payment_splits (
  id uuid primary key default gen_random_uuid(),
  payment_request_id uuid references public.payment_requests(id) on delete cascade,
  user_id uuid references public.users(id),
  amount numeric not null,
  is_paid boolean not null default false,
  created_at timestamptz default now(),
  unique(payment_request_id, user_id)
);

-- Also add venmo_username and paypal_username to users table
alter table public.users add column if not exists venmo_username text;
alter table public.users add column if not exists paypal_username text;

-- RLS
alter table public.payment_requests enable row level security;
alter table public.payment_splits enable row level security;

create policy "Members can view payment requests" on public.payment_requests
  for select using (exists (
    select 1 from public.home_members where home_id = payment_requests.home_id and user_id = auth.uid()
  ));

create policy "Members can create payment requests" on public.payment_requests
  for insert with check (auth.uid() = requestor_id);

create policy "Users can view their splits" on public.payment_splits
  for select using (true);

create policy "Users can update own split" on public.payment_splits
  for update using (auth.uid() = user_id);

create policy "Requestors can insert splits" on public.payment_splits
  for insert with check (true);
