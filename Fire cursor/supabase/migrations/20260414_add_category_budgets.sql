-- S0-2: Add category_budgets column to budgets table
-- Keys are canonical TransactionCategoryCatalog ids (e.g. "groceries", "dining_out"),
-- NOT display names, so renames/i18n never break stored data.
ALTER TABLE budgets
  ADD COLUMN IF NOT EXISTS category_budgets JSONB DEFAULT '{}'::jsonb;

COMMENT ON COLUMN budgets.category_budgets IS
  'Per-category budget amounts, keyed by TransactionCategoryCatalog.id (canonical stable id, NOT display name). Shape: { "groceries": 450, "dining_out": 200, ... }';
