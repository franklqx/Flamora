-- Starting Portfolio contract
-- FIRE projections should use investable retirement assets, not broad net worth.

ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS starting_portfolio_balance NUMERIC,
  ADD COLUMN IF NOT EXISTS starting_portfolio_source TEXT,
  ADD COLUMN IF NOT EXISTS starting_portfolio_updated_at TIMESTAMPTZ;

COMMENT ON COLUMN public.user_profiles.starting_portfolio_balance IS
  'Current FIRE projection starting portfolio: brokerage, retirement, investment accounts, and cash inside investment accounts.';

COMMENT ON COLUMN public.user_profiles.starting_portfolio_source IS
  'Source for starting_portfolio_balance: plaid_investment | manual_estimate | explicit_zero | unknown.';

COMMENT ON COLUMN public.user_profiles.starting_portfolio_updated_at IS
  'Timestamp when the starting portfolio value/source was last refreshed.';

ALTER TABLE public.active_plans
  ADD COLUMN IF NOT EXISTS starting_portfolio_balance NUMERIC,
  ADD COLUMN IF NOT EXISTS starting_portfolio_source TEXT;

COMMENT ON COLUMN public.active_plans.starting_portfolio_balance IS
  'Frozen starting portfolio balance used when this active plan was selected.';

COMMENT ON COLUMN public.active_plans.starting_portfolio_source IS
  'Frozen source for the starting portfolio used by this active plan.';

ALTER TABLE public.budgets
  ADD COLUMN IF NOT EXISTS snapshot_starting_portfolio_balance NUMERIC,
  ADD COLUMN IF NOT EXISTS snapshot_starting_portfolio_source TEXT;

COMMENT ON COLUMN public.budgets.snapshot_starting_portfolio_balance IS
  'Frozen starting portfolio balance used when this budget setup snapshot was confirmed.';

COMMENT ON COLUMN public.budgets.snapshot_starting_portfolio_source IS
  'Frozen source for snapshot_starting_portfolio_balance.';
