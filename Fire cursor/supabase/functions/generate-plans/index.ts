// supabase/functions/generate-plans/index.ts
//
// V2 Budget Module — Step 3
// Generates three budget plans (Steady / Recommended / Accelerate)
// based on flexible expense compression.
// Shows investment growth projections at 1, 5, 10 years.
//
// Replaces: calculate-fire-goal (V1)

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// ============================================================
// Global assumptions
// ============================================================

const NOMINAL_ANNUAL_RETURN = 0.08       // 8% nominal (S&P 500 long-run avg)
const INFLATION_RATE = 0.025             // 2.5% annual
const REAL_ANNUAL_RETURN = 0.055         // ~5.5% real return
const MONTHLY_REAL_RATE = REAL_ANNUAL_RETURN / 12

// Flexible compression ratios for the three plans
const COMPRESSION_STEADY = 0.10          // cut 10% of flexible spending
const COMPRESSION_RECOMMENDED = 0.25     // cut 25%
const COMPRESSION_ACCELERATE = 0.40      // cut 40%

// ============================================================
// Types
// ============================================================

interface GeneratePlansRequest {
  current_savings_rate: number
  avg_monthly_income: number
  avg_monthly_savings: number
  avg_monthly_fixed: number
  avg_monthly_flexible: number
  current_net_worth: number
  current_age: number
}

interface PlanDetail {
  savings_rate: number
  monthly_save: number
  monthly_spend: number
  flexible_spend: number
  extra_per_month: number
  flexible_compression_pct: number
  projection_1y: number
  projection_5y: number
  projection_10y: number
  gain_vs_baseline_10y: number
  feasibility: 'easy' | 'moderate' | 'challenging' | 'extreme'
  status: 'on_track' | 'breakeven' | 'deficit'
}

// ============================================================
// Core math
// ============================================================

function projectPortfolio(
  monthlySavings: number,
  startingPortfolio: number,
  years: number
): number {
  let portfolio = startingPortfolio
  const totalMonths = Math.round(years * 12)

  for (let m = 0; m < totalMonths; m++) {
    portfolio = portfolio * (1 + MONTHLY_REAL_RATE) + monthlySavings
  }

  return Math.round(portfolio * 100) / 100
}

function classifyFeasibility(planRate: number, currentRate: number): PlanDetail['feasibility'] {
  const jump = planRate - currentRate
  if (jump <= 5) return 'easy'
  if (jump <= 15) return 'moderate'
  if (jump <= 30) return 'challenging'
  return 'extreme'
}

function determineStatus(monthlySave: number, currentRate: number): PlanDetail['status'] {
  if (monthlySave < 0) return 'deficit'
  if (currentRate < 0 && monthlySave >= 0) return 'breakeven'
  return 'on_track'
}

function getUserTier(currentRate: number): string {
  if (currentRate < 0) return 'in_debt'
  if (currentRate < 10) return 'beginner'
  if (currentRate <= 30) return 'intermediate'
  return 'advanced'
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max)
}

function round2(value: number): number {
  return Math.round(value * 100) / 100
}

// ============================================================
// Plan generation
// ============================================================

function generateAllPlans(input: GeneratePlansRequest) {
  const {
    current_savings_rate: currentRate,
    avg_monthly_income: income,
    avg_monthly_savings: currentSavings,
    avg_monthly_fixed: fixed,
    avg_monthly_flexible: flexible,
    current_net_worth: netWorth,
  } = input

  // Step 1: Compute optimisable space
  const maxPossibleSavings = income - fixed
  const maxPossibleRate = income > 0 ? (maxPossibleSavings / income) * 100 : 0

  // Step 2: Raw rates from flexible compression
  let steadyRate = ((currentSavings + flexible * COMPRESSION_STEADY) / income) * 100
  let recommendedRate = ((currentSavings + flexible * COMPRESSION_RECOMMENDED) / income) * 100
  let accelerateRate = ((currentSavings + flexible * COMPRESSION_ACCELERATE) / income) * 100

  // Step 3: Handle negative savings rate
  if (currentRate < 0) {
    steadyRate = Math.max(0, steadyRate)
    recommendedRate = Math.max(5, recommendedRate)
    accelerateRate = Math.max(10, accelerateRate)
  } else {
    // Step 4: Floors and caps for positive savings rate

    // Steady: never recommend saving LESS than current rate
    const steadyFloor = Math.max(5, currentRate)
    steadyRate = Math.max(steadyRate, steadyFloor)
    const steadyCap = Math.max(
      maxPossibleRate * 0.6,
      currentRate + (flexible * COMPRESSION_STEADY / income) * 100
    )
    steadyRate = Math.min(steadyRate, steadyCap)

    // Recommended
    recommendedRate = clamp(recommendedRate, 10, maxPossibleRate * 0.8)

    // Accelerate
    accelerateRate = clamp(accelerateRate, 20, maxPossibleRate * 0.95)
  }

  // Step 5: Ensure monotonic ordering (min 3% gap)
  if (recommendedRate <= steadyRate + 3) {
    recommendedRate = steadyRate + 3
  }
  if (accelerateRate <= recommendedRate + 3) {
    accelerateRate = recommendedRate + 3
  }

  // Re-apply caps after gap adjustment
  if (currentRate >= 0) {
    recommendedRate = Math.min(recommendedRate, maxPossibleRate * 0.8)
    accelerateRate = Math.min(accelerateRate, maxPossibleRate * 0.95)
  }

  // Final safety: if caps caused ordering violations
  if (recommendedRate <= steadyRate) {
    recommendedRate = steadyRate + 2
  }
  if (accelerateRate <= recommendedRate) {
    accelerateRate = recommendedRate + 2
  }

  // Step 6: Compute "Do nothing" baseline
  const baselineSave = Math.max(0, currentSavings)
  const baseline = {
    savings_rate: round2(currentRate),
    monthly_save: round2(baselineSave),
    projection_1y: projectPortfolio(baselineSave, netWorth, 1),
    projection_5y: projectPortfolio(baselineSave, netWorth, 5),
    projection_10y: projectPortfolio(baselineSave, netWorth, 10),
  }

  // Step 7: Build each plan
  function buildPlan(rate: number): PlanDetail {
    const monthlySave = income * (rate / 100)
    const monthlySpend = income - monthlySave
    const flexibleSpend = Math.max(0, monthlySpend - fixed)
    const extra = monthlySave - currentSavings
    const compressionPct = flexible > 0
      ? round2((1 - flexibleSpend / flexible) * 100)
      : 0

    const p1y = projectPortfolio(monthlySave, netWorth, 1)
    const p5y = projectPortfolio(monthlySave, netWorth, 5)
    const p10y = projectPortfolio(monthlySave, netWorth, 10)

    return {
      savings_rate: round2(rate),
      monthly_save: round2(monthlySave),
      monthly_spend: round2(monthlySpend),
      flexible_spend: round2(flexibleSpend),
      extra_per_month: round2(extra),
      flexible_compression_pct: compressionPct,
      projection_1y: p1y,
      projection_5y: p5y,
      projection_10y: p10y,
      gain_vs_baseline_10y: round2(p10y - baseline.projection_10y),
      feasibility: classifyFeasibility(rate, currentRate),
      status: determineStatus(monthlySave, currentRate),
    }
  }

  const plans = {
    steady: buildPlan(steadyRate),
    recommended: buildPlan(recommendedRate),
    accelerate: buildPlan(accelerateRate),
  }

  // Step 8: Critical check — if even accelerate is deficit, fixed > income
  const critical = plans.accelerate.status === 'deficit'

  return { baseline, plans, maxPossibleRate, critical }
}

// ============================================================
// Main handler
// ============================================================

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
    const body: GeneratePlansRequest = await req.json()

    // Validate required fields
    if (!body.avg_monthly_income || body.avg_monthly_income <= 0) {
      return new Response(
        JSON.stringify({ success: false, error: { code: 'INVALID_INPUT', message: 'avg_monthly_income must be > 0' } }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ============================================================
    // 3. Get user profile for net worth and age (if not provided)
    // ============================================================
    let netWorth = body.current_net_worth
    let currentAge = body.current_age

    if (netWorth === undefined || netWorth === null || currentAge === undefined || currentAge === null) {
      const { data: profile } = await supabase
        .from('user_profiles')
        .select('age, current_net_worth, plaid_net_worth')
        .eq('user_id', user.id)
        .single()

      if (netWorth === undefined || netWorth === null) {
        netWorth = profile?.plaid_net_worth ?? profile?.current_net_worth ?? 0
      }
      if (currentAge === undefined || currentAge === null) {
        currentAge = profile?.age ?? 30
      }
    }

    // ============================================================
    // 4. Generate plans
    // ============================================================
    const input: GeneratePlansRequest = {
      ...body,
      current_net_worth: netWorth,
      current_age: currentAge,
    }

    const { baseline, plans, maxPossibleRate, critical } = generateAllPlans(input)

    // ============================================================
    // 5. Return
    // ============================================================
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          baseline,
          plans,
          user_tier: getUserTier(body.current_savings_rate),
          max_possible_rate: round2(maxPossibleRate),
          critical,
          current_net_worth: netWorth,
          current_age: currentAge,
          assumptions: {
            nominal_return: NOMINAL_ANNUAL_RETURN,
            inflation: INFLATION_RATE,
            real_return: REAL_ANNUAL_RETURN,
          },
        },
        meta: { timestamp: new Date().toISOString(), user_id: user.id },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in generate-plans:', error)
    return new Response(
      JSON.stringify({ success: false, error: { code: 'INTERNAL_SERVER_ERROR', message: error.message || 'An unexpected error occurred' } }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
