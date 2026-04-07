// supabase/functions/mark-setup-step/index.ts
//
// Marks a setup step as completed by upserting user_setup_state.
//
// Accepted steps:
//   "accounts_reviewed"  → sets accounts_reviewed_at
//   "snapshot_reviewed"  → sets snapshot_reviewed_at
//
// Idempotent: calling the same step twice is safe (timestamp only updates on first call).
// Returns the full current setup state row.

import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const VALID_STEPS = ['accounts_reviewed', 'snapshot_reviewed'] as const
type SetupStep = typeof VALID_STEPS[number]

Deno.serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    // ── 1. Auth ──────────────────────────────────────────────
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return errorResponse(401, 'UNAUTHORIZED', 'Missing Authorization header')

    const supabaseAuth = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    )
    const { data: { user }, error: authError } = await supabaseAuth.auth.getUser()
    if (authError || !user) return errorResponse(401, 'UNAUTHORIZED', 'Invalid token')

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // ── 2. Parse & validate ───────────────────────────────────
    const body = await req.json()
    const step: string = body.step

    if (!step || !VALID_STEPS.includes(step as SetupStep)) {
      return errorResponse(400, 'INVALID_STEP',
        `step must be one of: ${VALID_STEPS.join(', ')}`)
    }

    const now = new Date().toISOString()

    // ── 3. Fetch existing row (to preserve timestamps already set) ──
    const { data: existing } = await supabase
      .from('user_setup_state')
      .select('accounts_reviewed_at, snapshot_reviewed_at')
      .eq('user_id', user.id)
      .maybeSingle()

    // ── 4. Build upsert payload ───────────────────────────────
    // Only write the timestamp for the requested step.
    // Preserve existing timestamps — never overwrite a previously set one.
    const upsertPayload: Record<string, unknown> = {
      user_id:    user.id,
      updated_at: now,
      // Preserve existing values or keep null
      accounts_reviewed_at: existing?.accounts_reviewed_at ?? null,
      snapshot_reviewed_at: existing?.snapshot_reviewed_at ?? null,
    }

    // Set the requested step only if not already stamped (idempotent)
    if (step === 'accounts_reviewed' && !existing?.accounts_reviewed_at) {
      upsertPayload.accounts_reviewed_at = now
    }
    if (step === 'snapshot_reviewed' && !existing?.snapshot_reviewed_at) {
      upsertPayload.snapshot_reviewed_at = now
    }

    // ── 5. Upsert ─────────────────────────────────────────────
    const { data: updated, error: upsertError } = await supabase
      .from('user_setup_state')
      .upsert(upsertPayload, { onConflict: 'user_id' })
      .select()
      .single()

    if (upsertError) {
      console.error('Error upserting user_setup_state:', upsertError)
      return errorResponse(500, 'UPSERT_ERROR', 'Failed to mark setup step')
    }

    // ── 6. Return ─────────────────────────────────────────────
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          step_marked:          step,
          accounts_reviewed_at: updated.accounts_reviewed_at,
          snapshot_reviewed_at: updated.snapshot_reviewed_at,
          updated_at:           updated.updated_at,
        },
        meta: { timestamp: now, user_id: user.id },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in mark-setup-step:', error)
    return errorResponse(500, 'INTERNAL_SERVER_ERROR', error.message)
  }
})

function errorResponse(status: number, code: string, message: string): Response {
  return new Response(
    JSON.stringify({ success: false, error: { code, message } }),
    { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}
