-- Institution branding for plaid_items
-- Plaid /institutions/get_by_id returns logo (base64 PNG) + primary_color (hex).
-- We cache it on plaid_items so account list/summary functions can return it
-- without re-hitting Plaid on every request.

ALTER TABLE public.plaid_items
  ADD COLUMN IF NOT EXISTS institution_logo_base64 TEXT,
  ADD COLUMN IF NOT EXISTS institution_logo_url TEXT,
  ADD COLUMN IF NOT EXISTS institution_primary_color TEXT,
  ADD COLUMN IF NOT EXISTS institution_logo_fetched_at TIMESTAMPTZ;

COMMENT ON COLUMN public.plaid_items.institution_logo_base64 IS
  'Base64-encoded PNG logo for the institution, from Plaid /institutions/get_by_id (include_optional_metadata=true).';

COMMENT ON COLUMN public.plaid_items.institution_logo_url IS
  'Optional remote URL for the institution logo (currently unused — Plaid only returns base64).';

COMMENT ON COLUMN public.plaid_items.institution_primary_color IS
  'Institution primary brand color (hex like "#0a1d40"), used as a fallback tint when logo is unavailable.';

COMMENT ON COLUMN public.plaid_items.institution_logo_fetched_at IS
  'Timestamp when logo/primary_color were last refreshed from Plaid.';
