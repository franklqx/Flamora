// supabase/functions/apply-selected-plan/index.ts
//
// Turns a chosen plan (from generate-plans) into the official active plan.
// Writes to: active_plans, user_setup_state
// Does NOT write monthly_budgets — that remains saveFinalBudget() / generate-monthly-budget's job.
//
// Called from iOS after user taps "Use this plan" and budget is confirmed.

import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface ApplySelectedPlanRequest {
  plan_type:
    | 'steady'
    | 'recommended'
    | 'accelerate'
    | 'target-aligned'
    | 'comfortable'
    | 'accelerated'
    | 'closest_near'
    | 'closest_far'
    | 'already_fire'
    | 'custom'
  savings_target_monthly: number
  savings_rate_target: number
  spending_ceiling_monthly: number
  fixed_budget_monthly: number
  flexible_budget_monthly: number
  official_fire_date?: string | null
  official_fire_age?: number | null
  tradeoff_note?: string
  positioning_copy?: string
  starting_portfolio_balance?: number | null
  starting_portfolio_source?: string | null
}

const PLAN_LABELS: Record<string, string> = {
  steady:      'Steady',
  recommended: 'Recommended',
  accelerate:  'Accelerate',
  'target-aligned': 'Target-aligned',
  comfortable: 'Comfortable',
  accelerated: 'Accelerated',
  closest_near: 'Closest reasonable',
  closest_far: 'Adjust target',
  already_fire: 'Already FIRE',
  custom: 'Custom',
}

Deno.serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
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

    const body: ApplySelectedPlanRequest = await req.json()

    // ── Validate ──────────────────────────────────────────────
    const validPlanTypes = [
      'steady',
      'recommended',
      'accelerate',
      'target-aligned',
      'comfortable',
      'accelerated',
      'closest_near',
      'closest_far',
      'already_fire',
      'custom',
    ]
    if (!body.plan_type || !validPlanTypes.includes(body.plan_type)) {
      return errorResponse(400, 'INVALID_PLAN_TYPE', 'plan_type is not recognized')
    }
    if (!body.savings_target_monthly || body.savings_target_monthly < 0) {
      return errorResponse(400, 'INVALID_SAVINGS', 'savings_target_monthly must be >= 0')
    }
    if (!body.spending_ceiling_monthly || body.spending_ceiling_monthly < 0) {
      return errorResponse(400, 'INVALID_SPENDING', 'spending_ceiling_monthly must be >= 0')
    }

    const now = new Date().toISOString()

    // ── 1. Deactivate existing active plans ───────────────────
    await supabase
      .from('active_plans')
      .update({ is_active: false, updated_at: now })
      .eq('user_id', user.id)
      .eq('is_active', true)

    // ── 2. Insert new active plan ─────────────────────────────
    const { data: newPlan, error: insertError } = await supabase
      .from('active_plans')
      .insert({
        user_id:                  user.id,
        plan_type:                body.plan_type,
        plan_label:               PLAN_LABELS[body.plan_type] ?? body.plan_type,
        savings_target_monthly:   body.savings_target_monthly,
        savings_rate_target:      body.savings_rate_target,
        spending_ceiling_monthly: body.spending_ceiling_monthly,
        fixed_budget_monthly:     body.fixed_budget_monthly,
        flexible_budget_monthly:  body.flexible_budget_monthly,
        official_fire_date:       body.official_fire_date ?? null,
        official_fire_age:        body.official_fire_age  ?? null,
        tradeoff_note:            body.tradeoff_note       ?? null,
        positioning_copy:         body.positioning_copy    ?? null,
        starting_portfolio_balance: body.starting_portfolio_balance ?? null,
        starting_portfolio_source:  body.starting_portfolio_source  ?? null,
        is_active:                true,
        created_at:               now,
        updated_at:               now,
      })
      .select()
      .single()

    if (insertError) {
      console.error('Error inserting active plan:', insertError)
      return errorResponse(500, 'INSERT_ERROR', 'Failed to save active plan')
    }

    // ── 3. Upsert user_setup_state ────────────────────────────
    const { error: setupError } = await supabase
      .from('user_setup_state')
      .upsert(
        {
          user_id:         user.id,
          plan_applied_at: now,
          updated_at:      now,
        },
        { onConflict: 'user_id' }
      )

    if (setupError) {
      // Non-fatal: plan is saved; setup state update failed
      console.warn('Warning: failed to update user_setup_state:', setupError)
    }

    // ── 4. Return ─────────────────────────────────────────────
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          plan_id:                  newPlan.id,
          plan_type:                newPlan.plan_type,
          plan_label:               newPlan.plan_label,
          savings_target_monthly:   newPlan.savings_target_monthly,
          savings_rate_target:      newPlan.savings_rate_target,
          spending_ceiling_monthly: newPlan.spending_ceiling_monthly,
          fixed_budget_monthly:     newPlan.fixed_budget_monthly,
          flexible_budget_monthly:  newPlan.flexible_budget_monthly,
          official_fire_date:       newPlan.official_fire_date,
          official_fire_age:        newPlan.official_fire_age,
          tradeoff_note:            newPlan.tradeoff_note,
          positioning_copy:         newPlan.positioning_copy,
          starting_portfolio_balance: newPlan.starting_portfolio_balance,
          starting_portfolio_source:  newPlan.starting_portfolio_source,
          is_active:                newPlan.is_active,
          created_at:               newPlan.created_at,
        },
        meta: { timestamp: now, user_id: user.id },
      }),
      { status: 201, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in apply-selected-plan:', error)
    const message = error instanceof Error ? error.message : 'An unexpected error occurred'
    return errorResponse(500, 'INTERNAL_SERVER_ERROR', message)
  }
})

function errorResponse(status: number, code: string, message: string): Response {
  return new Response(
    JSON.stringify({ success: false, error: { code, message } }),
    { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}
