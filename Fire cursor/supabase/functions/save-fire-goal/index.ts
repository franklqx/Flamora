// supabase/functions/save-fire-goal/index.ts
//
// v3: Spending-based goal setup (v1 minimum flow)
//
// Breaking change from v2:
//   - target_retirement_age is now OPTIONAL (was required)
//   - current_age is now OPTIONAL (was required)
//   - retirement_spending_monthly + lifestyle_preset are the new v1 minimum fields
//   - fire_number can be provided by client OR computed server-side from spending
//   - selected_plan accepts new values: 'steady' | 'recommended' | 'accelerate' | 'current' | 'plan_a' | 'plan_b'
//
// Backward compat:
//   - Old requests with current_age + target_retirement_age + selected_plan (old values) still work
//   - fire_number, if provided by client, is used as-is (skip server computation)

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { computeFireNumber } from '../_shared/fire-math.ts'
import { ASSUMPTIONS } from '../_shared/fire-assumptions.ts'

interface SaveFireGoalRequest {
  // v1 minimum — spending-based goal
  retirement_spending_monthly?: number
  lifestyle_preset?: 'lean' | 'current' | 'fat'

  // Client-computed or passed through
  fire_number?: number

  // Optional (used if provided; not required in v1)
  current_age?: number
  target_retirement_age?: number
  required_monthly_contribution?: number
  required_savings_rate?: number

  // Plan selection (expanded set of accepted values)
  selected_plan?: 'steady' | 'recommended' | 'accelerate' | 'current' | 'plan_a' | 'plan_b' | 'recommended_legacy'

  // Assumption overrides (fall back to constants if absent)
  withdrawal_rate_assumption?: number
  inflation_assumption?: number
  return_assumption?: number

  // Legacy fields — accepted silently for backward compat
  desired_monthly_expenses?: number       // old name for retirement_spending_monthly
  adjustment_phase?: number
  adjustment_phase_sub?: string
  adjustment_strategy?: string
}

const DEFAULT_WITHDRAWAL_RATE = ASSUMPTIONS.WITHDRAWAL_RATE
const DEFAULT_INFLATION        = ASSUMPTIONS.INFLATION_RATE
const DEFAULT_RETURN_RATE      = ASSUMPTIONS.REAL_ANNUAL_RETURN

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    // ── 1. Auth ──────────────────────────────────────────────
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return errorResponse(401, 'UNAUTHORIZED', 'Missing Authorization header')
    }

    const supabaseAuth = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    )
    const { data: { user }, error: authError } = await supabaseAuth.auth.getUser()
    if (authError || !user) {
      return errorResponse(401, 'UNAUTHORIZED', 'Invalid token')
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // ── 2. Parse & resolve fields ─────────────────────────────
    const body: SaveFireGoalRequest = await req.json()

    // Support legacy field name
    const retirementSpending =
      body.retirement_spending_monthly ?? body.desired_monthly_expenses

    // Compute fire_number if not provided
    const withdrawalRate = body.withdrawal_rate_assumption ?? DEFAULT_WITHDRAWAL_RATE
    let fireNumber = body.fire_number
    if (!fireNumber || fireNumber <= 0) {
      if (retirementSpending && retirementSpending > 0) {
        fireNumber = computeFireNumber(retirementSpending, withdrawalRate)
      } else {
        return errorResponse(400, 'MISSING_GOAL',
          'Provide either fire_number or retirement_spending_monthly')
      }
    }

    // required_savings_rate defaults to 0 when absent (v1 flow computes this later)
    const savingsRate = body.required_savings_rate ?? 0

    // Validate optional age fields only when both are provided
    if (
      body.current_age != null &&
      body.target_retirement_age != null &&
      body.target_retirement_age <= body.current_age
    ) {
      return errorResponse(400, 'INVALID_RETIREMENT_AGE',
        'target_retirement_age must be greater than current_age')
    }

    // ── 3. Deactivate existing active goals ───────────────────
    await supabase
      .from('fire_goals')
      .update({ is_active: false })
      .eq('user_id', user.id)
      .eq('is_active', true)

    // ── 4. Insert new FIRE goal ───────────────────────────────
    const { data: fireGoal, error: insertError } = await supabase
      .from('fire_goals')
      .insert({
        user_id:                      user.id,
        fire_number:                  fireNumber,
        required_savings_rate:        savingsRate,
        required_monthly_contribution: body.required_monthly_contribution ?? 0,

        // Spending-based fields (v1)
        retirement_spending_monthly:  retirementSpending ?? null,
        lifestyle_preset:             body.lifestyle_preset ?? null,

        // Optional age fields
        current_age:                  body.current_age ?? null,
        target_retirement_age:        body.target_retirement_age ?? null,

        // Backward-compat field (desired_monthly_expenses kept for old reads)
        desired_monthly_expenses:     retirementSpending ?? null,

        // Assumptions
        withdrawal_rate_assumption:   withdrawalRate,
        inflation_assumption:         body.inflation_assumption ?? DEFAULT_INFLATION,
        return_assumption:            body.return_assumption    ?? DEFAULT_RETURN_RATE,
        assumed_annual_return:        body.return_assumption    ?? DEFAULT_RETURN_RATE,
        assumed_inflation_rate:       body.inflation_assumption ?? DEFAULT_INFLATION,
        assumed_withdrawal_rate:      withdrawalRate,

        // Plan / strategy metadata
        user_selected_plan:           body.selected_plan ?? null,
        adjustment_phase:             body.adjustment_phase ?? 0,
        adjustment_phase_sub:         body.adjustment_phase_sub ?? '0b',
        adjustment_strategy:          body.adjustment_strategy ?? 'goal_achievable',

        is_active: true,
      })
      .select()
      .single()

    if (insertError) {
      console.error('Error inserting fire goal:', insertError)
      return errorResponse(500, 'INSERT_ERROR', 'Failed to save FIRE goal')
    }

    // ── 5. Return ─────────────────────────────────────────────
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          goal_id:                     fireGoal.id,
          user_id:                     fireGoal.user_id,
          fire_number:                 fireGoal.fire_number,
          retirement_spending_monthly: fireGoal.retirement_spending_monthly,
          lifestyle_preset:            fireGoal.lifestyle_preset,
          required_savings_rate:       fireGoal.required_savings_rate,
          required_monthly_contribution: fireGoal.required_monthly_contribution,
          target_retirement_age:       fireGoal.target_retirement_age,
          current_age:                 fireGoal.current_age,
          selected_plan:               fireGoal.user_selected_plan,
          adjustment_phase:            fireGoal.adjustment_phase,
          adjustment_phase_sub:        fireGoal.adjustment_phase_sub,
          withdrawal_rate_assumption:  fireGoal.withdrawal_rate_assumption,
          inflation_assumption:        fireGoal.inflation_assumption,
          return_assumption:           fireGoal.return_assumption,
          is_active:                   fireGoal.is_active,
        },
        meta: {
          timestamp: new Date().toISOString(),
          user_id: user.id,
        },
      }),
      { status: 201, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in save-fire-goal:', error)
    return errorResponse(500, 'INTERNAL_SERVER_ERROR', error.message)
  }
})

function errorResponse(status: number, code: string, message: string): Response {
  return new Response(
    JSON.stringify({ success: false, error: { code, message } }),
    { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}
