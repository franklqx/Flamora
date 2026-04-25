// supabase/functions/calculate-fire-goal/index.ts
//
// UPDATED v2: Works with fire-calculator v2
// - Phase 0a-d / 1 / 2 (was 0 / 2 / 3)
// - Unified 9% return rate
// - Tighter input validation (min target = current_age + 5, max = 75)
// - Calculator now throws on invalid inputs

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { FIRECalculator } from '../_shared/fire-calculator.ts'
import { ASSUMPTIONS } from '../_shared/fire-assumptions.ts'

interface CalculateFireGoalRequest {
  target_retirement_age: number
  // Optional overrides (if not provided, fetched from user_profiles)
  current_age?: number
  desired_monthly_expenses?: number
  current_net_worth?: number
  starting_portfolio_balance?: number
  monthly_income?: number
  current_monthly_expenses?: number
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
    // 2. Parse request
    // ============================================================
    const body: CalculateFireGoalRequest = await req.json()

    if (!body.target_retirement_age) {
      return new Response(
        JSON.stringify({ success: false, error: { code: 'MISSING_FIELD', message: 'target_retirement_age is required' } }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ============================================================
    // 3. Get user data (from profile or request overrides)
    // ============================================================
    const { data: profile, error: profileError } = await supabase
      .from('user_profiles')
      .select('age, monthly_income, current_monthly_expenses, current_net_worth, plaid_net_worth, starting_portfolio_balance')
      .eq('user_id', user.id)
      .single()

    if (profileError || !profile) {
      return new Response(
        JSON.stringify({ success: false, error: { code: 'PROFILE_NOT_FOUND', message: 'User profile not found' } }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // FIRE feasibility uses the starting portfolio contract, with legacy
    // net-worth fields retained as fallback for older clients.
    const netWorth = body.starting_portfolio_balance
      ?? body.current_net_worth
      ?? profile.starting_portfolio_balance
      ?? profile.plaid_net_worth
      ?? profile.current_net_worth
      ?? 0
    const monthlyIncome = body.monthly_income ?? profile.monthly_income ?? 0
    const currentExpenses = body.current_monthly_expenses ?? profile.current_monthly_expenses ?? 0
    const currentAge = body.current_age ?? profile.age ?? 28
    const desiredMonthlyExpenses = body.desired_monthly_expenses ?? currentExpenses

    // ============================================================
    // 4. Calculate
    // ============================================================
    const calculator = new FIRECalculator()

    let result
    try {
      result = calculator.adjustGoal({
        monthlyIncome,
        currentAge,
        targetRetirementAge: body.target_retirement_age,
        desiredMonthlyExpenses: desiredMonthlyExpenses,
        currentNetWorth: netWorth,
        currentMonthlyExpenses: currentExpenses,
      })
    } catch (calcError) {
      // Calculator throws on invalid inputs (income=0, bad age range, etc.)
      const message = calcError instanceof Error ? calcError.message : 'Calculation failed'
      const code = message.includes(':') ? message.split(':')[0] : 'CALCULATION_ERROR'
      return new Response(
        JSON.stringify({ success: false, error: { code, message } }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ============================================================
    // 5. Return
    // ============================================================
    return new Response(
      JSON.stringify({
        success: true,
        data: result,
        meta: {
          timestamp: new Date().toISOString(),
          user_id: user.id,
          return_rate_assumption: ASSUMPTIONS.REAL_ANNUAL_RETURN,
          withdrawal_rate: ASSUMPTIONS.WITHDRAWAL_RATE,
          inputs: {
            current_age: currentAge,
            target_retirement_age: body.target_retirement_age,
            desired_monthly_expenses: desiredMonthlyExpenses,
            current_net_worth: netWorth,
            starting_portfolio_balance: netWorth,
            monthly_income: monthlyIncome,
            current_monthly_expenses: currentExpenses,
            net_worth_source: profile.starting_portfolio_balance != null
              ? 'starting_portfolio'
              : (profile.plaid_net_worth ? 'plaid' : 'manual'),
          },
        },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in calculate-fire-goal:', error)
    return new Response(
      JSON.stringify({ success: false, error: { code: 'INTERNAL_SERVER_ERROR', message: error.message || 'An unexpected error occurred' } }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
