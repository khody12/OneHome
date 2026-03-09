-- =============================================================
-- home_features_schema.sql
-- Tables: subscriptions, subscription_members, spend_logs
-- Run this against your Supabase project (SQL Editor or CLI).
-- =============================================================

-- ---------------------------------------------------------------
-- subscriptions
-- ---------------------------------------------------------------
create table if not exists subscriptions (
    id              uuid primary key default gen_random_uuid(),
    home_id         uuid not null references homes(id) on delete cascade,
    created_by_id   uuid not null references users(id) on delete cascade,
    service_name    text not null,
    service_icon    text not null default '📱',
    monthly_cost    numeric(10,2) not null check (monthly_cost > 0),
    billing_day     int not null default 1 check (billing_day between 1 and 28),
    created_at      timestamptz not null default now()
);

create index if not exists subscriptions_home_id_idx on subscriptions(home_id);

-- Row-Level Security
alter table subscriptions enable row level security;

-- Members of the home can read subscriptions for that home
create policy "Home members can view subscriptions"
    on subscriptions for select
    using (
        exists (
            select 1 from home_members
            where home_members.home_id = subscriptions.home_id
              and home_members.user_id = auth.uid()
        )
    );

-- Any home member can create a subscription
create policy "Home members can create subscriptions"
    on subscriptions for insert
    with check (
        exists (
            select 1 from home_members
            where home_members.home_id = subscriptions.home_id
              and home_members.user_id = auth.uid()
        )
    );

-- Only the creator can update or delete
create policy "Creator can update subscription"
    on subscriptions for update
    using (created_by_id = auth.uid());

create policy "Creator can delete subscription"
    on subscriptions for delete
    using (created_by_id = auth.uid());

-- ---------------------------------------------------------------
-- subscription_members  (junction: subscription <-> user)
-- ---------------------------------------------------------------
create table if not exists subscription_members (
    id               uuid primary key default gen_random_uuid(),
    subscription_id  uuid not null references subscriptions(id) on delete cascade,
    user_id          uuid not null references users(id) on delete cascade,
    unique (subscription_id, user_id)
);

create index if not exists subscription_members_sub_idx  on subscription_members(subscription_id);
create index if not exists subscription_members_user_idx on subscription_members(user_id);

alter table subscription_members enable row level security;

-- Readable by anyone in the same home as the subscription
create policy "Home members can view subscription members"
    on subscription_members for select
    using (
        exists (
            select 1
            from subscriptions s
            join home_members hm on hm.home_id = s.home_id
            where s.id = subscription_members.subscription_id
              and hm.user_id = auth.uid()
        )
    );

-- Any home member can add/remove members of a subscription they belong to
create policy "Home members can insert subscription members"
    on subscription_members for insert
    with check (
        exists (
            select 1
            from subscriptions s
            join home_members hm on hm.home_id = s.home_id
            where s.id = subscription_members.subscription_id
              and hm.user_id = auth.uid()
        )
    );

create policy "Home members can delete subscription members"
    on subscription_members for delete
    using (
        exists (
            select 1
            from subscriptions s
            join home_members hm on hm.home_id = s.home_id
            where s.id = subscription_members.subscription_id
              and hm.user_id = auth.uid()
        )
    );

-- ---------------------------------------------------------------
-- spend_logs
-- ---------------------------------------------------------------
create table if not exists spend_logs (
    id          uuid primary key default gen_random_uuid(),
    home_id     uuid not null references homes(id) on delete cascade,
    user_id     uuid not null references users(id) on delete cascade,
    amount      numeric(10,2) not null check (amount > 0),
    category    text not null default 'other'
                    check (category in ('food','household','utilities','entertainment','other')),
    note        text not null default '',
    created_at  timestamptz not null default now()
);

create index if not exists spend_logs_home_id_idx on spend_logs(home_id);
create index if not exists spend_logs_user_id_idx on spend_logs(user_id);
create index if not exists spend_logs_created_at_idx on spend_logs(created_at desc);

alter table spend_logs enable row level security;

-- Home members can read spend logs for their home
create policy "Home members can view spend logs"
    on spend_logs for select
    using (
        exists (
            select 1 from home_members
            where home_members.home_id = spend_logs.home_id
              and home_members.user_id = auth.uid()
        )
    );

-- Home members can log spend in their home
create policy "Home members can create spend logs"
    on spend_logs for insert
    with check (
        user_id = auth.uid()
        and exists (
            select 1 from home_members
            where home_members.home_id = spend_logs.home_id
              and home_members.user_id = auth.uid()
        )
    );

-- Only the author can delete their own log entry
create policy "Author can delete spend log"
    on spend_logs for delete
    using (user_id = auth.uid());
