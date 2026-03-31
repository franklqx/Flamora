// supabase/functions/save-fire-goal/index.ts
//
// UPDATED v2: Unified 9% return rate, Phase 0/1/2 (was 0/2/3),
// added phase_sub field, expanded selected_plan options

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface SaveFireGoalRequest {
  current_age: number
  target_retirement_age: number
  desired_monthly_expenses: number
  fire_number: number
  required_monthly_contribution: number
  required_savings_rate: number

  // Which plan the user chose
  selected_plan: 'current' | 'plan_a' | 'plan_b' | 'recommended'

  // Phase / strategy from calculate-fire-goal
  adjustment_phase?: number           // 0, 1, or 2
  adjustment_phase_sub?: string       // NEW: '0a', '0b', '0c', '0d', '1', '2'
  adjustment_strategy?: string
}

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    // ============================================================
    // 1. Auth
    // ============================================================
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, error: { code: 'UNAUTHORIZED', message: 'Missing Authorization header' } }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabaseAuth = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error: authError } = await supabaseAuth.auth.getUser()
    if (authError || !user) {
      return new Response(
        JSON.stringify({ success: false, error: { code: 'UNAUTHORIZED', message: 'Invalid token' } }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // ============================================================
    // 2. Parse & validate
    // ============================================================
    const body: SaveFireGoalRequest = await req.json()

    const validationError = validateInput(body)
    if (validationError) {
      return new Response(
        JSON.stringify({ success: false, error: validationError }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ============================================================
    // 3. Deactivate existing active goals
    // ============================================================
    const { error: deactivateError } = await supabase
      .from('fire_goals')
      .update({ is_active: false })
      .eq('user_id', user.id)
      .eq('is_active', true)

    if (deactivateError) {
      console.error('Error deactivating old goals:', deactivateError)
    }

    // ============================================================
    // 4. Insert new FIRE goal
    // ============================================================
    const { data: fireGoal, error: insertError } = await supabase
      .from('fire_goals')
      .insert({
        user_id: user.id,
        current_age: body.current_age,
        target_retirement_age: body.target_retirement_age,
        desired_monthly_expenses: body.desired_monthly_expenses,
        fire_number: body.fire_number,
        required_monthly_contribution: body.required_monthly_contribution,
        required_savings_rate: body.required_savings_rate,
        adjustment_phase: body.adjustment_phase ?? 0,
        adjustment_phase_sub: body.adjustment_phase_sub ?? '0b',   // NEW
        adjustment_strategy: body.adjustment_strategy ?? 'goal_achievable',
        user_selected_plan: body.selected_plan,
        assumed_annual_return: 0.09,                                // CHANGED: was 0.08
        assumed_inflation_rate: 0.03,
        assumed_withdrawal_rate: 0.04,
        is_active: true,
      })
      .select()
      .single()

    if (insertError) {
      console.error('Error inserting fire goal:', insertError)
      return new Response(
        JSON.stringify({ success: false, error: { code: 'INSERT_ERROR', message: 'Failed to save FIRE goal', details: insertError.message } }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ============================================================
    // 5. Return
    // ============================================================
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          goal_id: fireGoal.id,
          user_id: fireGoal.user_id,
          target_retirement_age: fireGoal.target_retirement_age,
          fire_number: fireGoal.fire_number,
          required_savings_rate: fireGoal.required_savings_rate,
          required_monthly_contribution: fireGoal.required_monthly_contribution,
          selected_plan: fireGoal.user_selected_plan,
          adjustment_phase: fireGoal.adjustment_phase,
          adjustment_phase_sub: fireGoal.adjustment_phase_sub,     // NEW
          is_active: fireGoal.is_active,
        },
        meta: {
          timestamp: new Date().toISOString(),
          user_id: user.id,
          return_rate_assumption: 0.09,                             // NEW
        },
      }),
      { status: 201, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in save-fire-goal:', error)
    return new Response(
      JSON.stringify({ success: false, error: { code: 'INTERNAL_SERVER_ERROR', message: error.message || 'An unexpected error occurred' } }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

function validateInput(body: SaveFireGoalRequest) {
  if (!body.current_age || body.current_age < 18 || body.current_age > 100) {
    return { code: 'INVALID_AGE', message: 'Age must be between 18 and 100' }
  }
  if (!body.target_retirement_age || body.target_retirement_age <= body.current_age) {
    return { code: 'INVALID_RETIREMENT_AGE', message: 'Target retirement age must be greater than current age' }
  }
  if (!body.fire_number || body.fire_number <= 0) {
    return { code: 'INVALID_FIRE_NUMBER', message: 'FIRE number must be greater than 0' }
  }
  if (body.required_savings_rate < 0) {
    return { code: 'INVALID_RATE', message: 'Savings rate must be >= 0' }  // CHANGED: removed upper cap of 100 (Phase 0a can have rate=0)
  }
  const validPlans = ['current', 'plan_a', 'plan_b', 'recommended']
  if (!body.selected_plan || !validPlans.includes(body.selected_plan)) {
    return { code: 'INVALID_PLAN', message: 'selected_plan must be one of: current, plan_a, plan_b, recommended' }
  }
  return null
}