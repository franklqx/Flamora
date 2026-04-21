-- ============================================================
-- Migration: 2026-04-20 Story Reports + Archive
-- 1. Create report_snapshots
-- 2. Extend user_setup_state for Issue Zero lifecycle
-- ============================================================

CREATE TABLE IF NOT EXISTS public.report_snapshots (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kind            TEXT NOT NULL CHECK (kind IN ('weekly', 'monthly', 'annual', 'issue_zero')),
  period_start    DATE NOT NULL,
  period_end      DATE NOT NULL,
  period_label    TEXT NOT NULL,
  title           TEXT NOT NULL,
  status          TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'ready', 'failed')),
  story_payload   JSONB NOT NULL DEFAULT '[]'::jsonb,
  metrics_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  insight_text    TEXT,
  insight_provider TEXT,
  generated_at    TIMESTAMPTZ,
  viewed_at       TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_report_snapshots_unique_period
  ON public.report_snapshots (user_id, kind, period_start, period_end);

CREATE INDEX IF NOT EXISTS idx_report_snapshots_user_generated
  ON public.report_snapshots (user_id, generated_at DESC, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_report_snapshots_user_status
  ON public.report_snapshots (user_id, status, kind);

ALTER TABLE public.report_snapshots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read their own report snapshots" ON public.report_snapshots;
CREATE POLICY "Users can read their own report snapshots"
  ON public.report_snapshots FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own report snapshots" ON public.report_snapshots;
CREATE POLICY "Users can insert their own report snapshots"
  ON public.report_snapshots FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own report snapshots" ON public.report_snapshots;
CREATE POLICY "Users can update their own report snapshots"
  ON public.report_snapshots FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

ALTER TABLE public.user_setup_state
  ADD COLUMN IF NOT EXISTS first_bank_connected_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS issue_zero_generated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS issue_zero_viewed_at TIMESTAMPTZ;
