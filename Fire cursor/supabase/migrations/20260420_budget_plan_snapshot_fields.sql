-- Phase D: store committed plan + setup snapshot fields on budgets
-- Matches budget-plan-budget-plan-gentle-blossom.md "数据模型 (DB / Swift)" section.

ALTER TABLE budgets
  ADD COLUMN IF NOT EXISTS committed_savings_rate NUMERIC,
  ADD COLUMN IF NOT EXISTS committed_monthly_save NUMERIC,
  ADD COLUMN IF NOT EXISTS committed_spend_ceiling NUMERIC,
  ADD COLUMN IF NOT EXISTS committed_plan_label TEXT,
  ADD COLUMN IF NOT EXISTS snapshot_avg_income NUMERIC,
  ADD COLUMN IF NOT EXISTS snapshot_avg_spend NUMERIC,
  ADD COLUMN IF NOT EXISTS snapshot_net_worth NUMERIC,
  ADD COLUMN IF NOT EXISTS snapshot_essential_floor NUMERIC,
  ADD COLUMN IF NOT EXISTS snapshot_date TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS retirement_spending_monthly NUMERIC;

COMMENT ON COLUMN budgets.committed_savings_rate IS
  'Committed savings ratio from Budget Setup Step 5/6, stored as 0..1.';

COMMENT ON COLUMN budgets.committed_monthly_save IS
  'Committed monthly savings amount chosen in Budget Setup Step 5.';

COMMENT ON COLUMN budgets.committed_spend_ceiling IS
  'Committed monthly spending ceiling. Usually income - save; already_fire uses retirement spending.';

COMMENT ON COLUMN budgets.committed_plan_label IS
  'Step 5 committed plan label: target-aligned | comfortable | accelerated | closest_near | closest_far | already_fire | custom.';

COMMENT ON COLUMN budgets.snapshot_avg_income IS
  'Frozen setup snapshot average monthly income used when the plan was confirmed.';

COMMENT ON COLUMN budgets.snapshot_avg_spend IS
  'Frozen setup snapshot average monthly spend used when the plan was confirmed.';

COMMENT ON COLUMN budgets.snapshot_net_worth IS
  'Frozen setup snapshot net worth used when the plan was confirmed.';

COMMENT ON COLUMN budgets.snapshot_essential_floor IS
  'Frozen setup snapshot essential floor used when the plan was confirmed.';

COMMENT ON COLUMN budgets.snapshot_date IS
  'Timestamp when the setup snapshot was frozen during Budget Setup.';

COMMENT ON COLUMN budgets.retirement_spending_monthly IS
  'User-entered retirement monthly spending target from Step 4.';
