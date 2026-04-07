-- ============================================================
-- Migration: 2026-04-08 active_plans one-active-per-user constraint
--
-- Why a partial unique index instead of a trigger or CHECK:
--   - Enforced atomically by Postgres at insert/update time — no race condition
--   - Only constrains rows WHERE is_active = true, so historical inactive rows
--     (the full plan history) are unrestricted
--   - apply-selected-plan already sets old rows to is_active = false before
--     inserting the new one; this index is the safety net if that logic ever fails
--   - Lighter than a trigger (no PL/pgSQL overhead per row)
-- ============================================================

CREATE UNIQUE INDEX IF NOT EXISTS idx_active_plans_one_per_user
  ON public.active_plans (user_id)
  WHERE (is_active = true);
