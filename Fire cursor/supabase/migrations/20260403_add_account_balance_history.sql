create extension if not exists pgcrypto;

create table if not exists public.account_balance_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plaid_account_id uuid not null references public.plaid_accounts(id) on delete cascade,
  date date not null,
  account_type text not null,
  current_balance numeric(14,2),
  available_balance numeric(14,2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, plaid_account_id, date)
);

create index if not exists idx_account_balance_history_user_date
  on public.account_balance_history (user_id, date desc);

create index if not exists idx_account_balance_history_account_date
  on public.account_balance_history (plaid_account_id, date desc);

alter table public.account_balance_history enable row level security;

drop policy if exists "Users can read their own account balance history" on public.account_balance_history;
create policy "Users can read their own account balance history"
  on public.account_balance_history
  for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their own account balance history" on public.account_balance_history;
create policy "Users can insert their own account balance history"
  on public.account_balance_history
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own account balance history" on public.account_balance_history;
create policy "Users can update their own account balance history"
  on public.account_balance_history
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
