-- ============================================================
-- Migration: 2026-04-07 Home / Plan System Rebuild
-- 1. Extend fire_goals — make age optional, add spending-based fields
-- 2. Create user_setup_state — resumable setup progress
-- 3. Create active_plans — official active plan record
-- ============================================================

-- ------------------------------------------------------------
-- 1. Extend fire_goals
-- ------------------------------------------------------------

-- v1 minimum goal fields
ALTER TABLE public.fire_goals
  ADD COLUMN IF NOT EXISTS retirement_spending_monthly NUMERIC(14,2),
  ADD COLUMN IF NOT EXISTS lifestyle_preset TEXT;           -- 'lean' | 'current' | 'fat'

-- Assumption overrides (server uses these; defaults already stored as constants)
ALTER TABLE public.fire_goals
  ADD COLUMN IF NOT EXISTS withdrawal_rate_assumption NUMERIC(6,4) DEFAULT 0.04,
  ADD COLUMN IF NOT EXISTS inflation_assumption       NUMERIC(6,4) DEFAULT 0.03,
  ADD COLUMN IF NOT EXISTS return_assumption          NUMERIC(6,4) DEFAULT 0.07;

-- Make formerly-required age fields optional (existing rows keep their values)
ALTER TABLE public.fire_goals
  ALTER COLUMN target_retirement_age DROP NOT NULL,
  ALTER COLUMN current_age           DROP NOT NULL;

-- ------------------------------------------------------------
-- 2. Create user_setup_state
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.user_setup_state (
  user_id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  accounts_reviewed_at TIMESTAMPTZ,
  snapshot_reviewed_at TIMESTAMPTZ,
  plan_applied_at      TIMESTAMPTZ,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.user_setup_state ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read their own setup state" ON public.user_setup_state;
CREATE POLICY "Users can read their own setup state"
  ON public.user_setup_state FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can upsert their own setup state" ON public.user_setup_state;
CREATE POLICY "Users can upsert their own setup state"
  ON public.user_setup_state FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ------------------------------------------------------------
-- 3. Create active_plans
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.active_plans (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                 UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plan_type               TEXT NOT NULL,            -- 'steady' | 'recommended' | 'accelerate'
  plan_label              TEXT NOT NULL,
  savings_target_monthly  NUMERIC(14,2) NOT NULL,
  savings_rate_target     NUMERIC(6,2)  NOT NULL,
  spending_ceiling_monthly NUMERIC(14,2) NOT NULL,
  fixed_budget_monthly    NUMERIC(14,2) NOT NULL,
  flexible_budget_monthly NUMERIC(14,2) NOT NULL,
  official_fire_date      TEXT,                     -- "Mar 2042"
  official_fire_age       INT,
  tradeoff_note           TEXT,
  positioning_copy        TEXT,
  is_active               BOOLEAN NOT NULL DEFAULT true,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_active_plans_user_active
  ON public.active_plans (user_id, is_active);

ALTER TABLE public.active_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read their own active plans" ON public.active_plans;
CREATE POLICY "Users can read their own active plans"
  ON public.active_plans FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own active plans" ON public.active_plans;
CREATE POLICY "Users can insert their own active plans"
  ON public.active_plans FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own active plans" ON public.active_plans;
CREATE POLICY "Users can update their own active plans"
  ON public.active_plans FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
