// supabase/functions/generate-plans/index.ts
//
// V3 Budget Module — Plan generation
// Generates Steady / Recommended / Accelerate plans.
// Each plan now includes:
//   - official_fire_date / official_fire_age (projected at that plan's savings rate)
//   - spending_ceiling_monthly (= monthly_spend, aliased for clarity)
//   - tradeoff_note (human-readable delta vs baseline)
//   - positioning_copy (Hero voice one-liner)
//   - fire_years_vs_baseline (years saved relative to "do nothing")
//
// All new fields are additive — old iOS clients that ignore unknown keys are unaffected.

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import {
  computeFireDate,
  computeFireNumber,
  getPositioningCopy,
  buildTradeoffNote,
} from '../_shared/fire-math.ts'

// ── Global assumptions ────────────────────────────────────────
const NOMINAL_ANNUAL_RETURN = 0.08
const INFLATION_RATE        = 0.025
const REAL_ANNUAL_RETURN    = 0.055
const MONTHLY_REAL_RATE     = REAL_ANNUAL_RETURN / 12

// Flexible compression ratios
const COMPRESSION_STEADY      = 0.10
const COMPRESSION_RECOMMENDED = 0.25
const COMPRESSION_ACCELERATE  = 0.40

// ── Types ─────────────────────────────────────────────────────
interface GeneratePlansRequest {
  current_savings_rate: number
  avg_monthly_income: number
  avg_monthly_savings: number
  avg_monthly_fixed: number
  avg_monthly_flexible: number
  current_net_worth?: number
  current_age?: number
  // New optional: if provided, enables FIRE date projection per plan
  fire_number?: number
  retirement_spending_monthly?: number
  return_assumption?: number    // override (default: REAL_ANNUAL_RETURN)
}

interface PlanDetail {
  savings_rate: number
  monthly_save: number
  monthly_spend: number
  spending_ceiling_monthly: number  // NEW: alias for monthly_spend, clearer name
  flexible_spend: number
  extra_per_month: number
  flexible_compression_pct: number
  projection_1y: number
  projection_5y: number
  projection_10y: number
  gain_vs_baseline_10y: number
  feasibility: 'easy' | 'moderate' | 'challenging' | 'extreme'
  status: 'on_track' | 'breakeven' | 'deficit'
  // NEW: FIRE-aware fields
  official_fire_date: string | null
  official_fire_age: number | null
  fire_years_vs_baseline: number | null
  tradeoff_note: string
  positioning_copy: string
}

// ── Core portfolio math ───────────────────────────────────────

function projectPortfolio(monthlySavings: number, startingPortfolio: number, years: number): number {
  let portfolio = startingPortfolio
  const totalMonths = Math.round(years * 12)
  for (let m = 0; m < totalMonths; m++) {
    portfolio = portfolio * (1 + MONTHLY_REAL_RATE) + monthlySavings
  }
  return Math.round(portfolio * 100) / 100
}

function classifyFeasibility(planRate: number, currentRate: number): PlanDetail['feasibility'] {
  const jump = planRate - currentRate
  if (jump <= 5)  return 'easy'
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
  if (currentRate < 0)  return 'in_debt'
  if (currentRate < 10) return 'beginner'
  if (currentRate <= 30) return 'intermediate'
  return 'advanced'
}

function clamp(v: number, min: number, max: number): number {
  return Math.min(Math.max(v, min), max)
}

function round2(v: number): number { return Math.round(v * 100) / 100 }
function roundMoney(v: number): number { return Math.round(v / 10) * 10 }
function roundRate(v: number): number { return Math.round(v * 10) / 10 }

// ── Plan generation ───────────────────────────────────────────

function generateAllPlans(
  input: Required<Pick<GeneratePlansRequest,
    'current_savings_rate' | 'avg_monthly_income' | 'avg_monthly_savings' |
    'avg_monthly_fixed' | 'avg_monthly_flexible' | 'current_net_worth' | 'current_age'
  >> & {
    fire_number: number | null
    return_assumption: number
  }
) {
  const {
    current_savings_rate: currentRate,
    avg_monthly_income: income,
    avg_monthly_savings: currentSavings,
    avg_monthly_fixed: fixed,
    avg_monthly_flexible: flexible,
    current_net_worth: netWorth,
    fire_number: fireNumber,
    return_assumption: returnRate,
  } = input

  const currentAge = input.current_age

  // ── Rate computation (unchanged from v2) ──
  const maxPossibleSavings = income - fixed
  const maxPossibleRate    = income > 0 ? (maxPossibleSavings / income) * 100 : 0

  let steadyRate      = ((currentSavings + flexible * COMPRESSION_STEADY)      / income) * 100
  let recommendedRate = ((currentSavings + flexible * COMPRESSION_RECOMMENDED) / income) * 100
  let accelerateRate  = ((currentSavings + flexible * COMPRESSION_ACCELERATE)  / income) * 100

  if (currentRate < 0) {
    steadyRate      = Math.max(0,  steadyRate)
    recommendedRate = Math.max(5,  recommendedRate)
    accelerateRate  = Math.max(10, accelerateRate)
  } else {
    const steadyFloor = Math.max(5, currentRate)
    steadyRate = Math.max(steadyRate, steadyFloor)
    const steadyCap = Math.max(
      maxPossibleRate * 0.6,
      currentRate + (flexible * COMPRESSION_STEADY / income) * 100
    )
    steadyRate      = Math.min(steadyRate, steadyCap)
    recommendedRate = clamp(recommendedRate, 10, maxPossibleRate * 0.8)
    accelerateRate  = clamp(accelerateRate, 20, maxPossibleRate * 0.95)
  }

  if (recommendedRate <= steadyRate + 3) recommendedRate = steadyRate + 3
  if (accelerateRate  <= recommendedRate + 3) accelerateRate = recommendedRate + 3

  if (currentRate >= 0) {
    recommendedRate = Math.min(recommendedRate, maxPossibleRate * 0.8)
    accelerateRate  = Math.min(accelerateRate,  maxPossibleRate * 0.95)
  }
  if (recommendedRate <= steadyRate)   recommendedRate = steadyRate + 2
  if (accelerateRate  <= recommendedRate) accelerateRate = recommendedRate + 2

  // ── Baseline ──
  const baselineSave = roundMoney(Math.max(0, currentSavings))
  const baseline = {
    savings_rate:   roundRate(currentRate),
    monthly_save:   baselineSave,
    projection_1y:  projectPortfolio(baselineSave, netWorth, 1),
    projection_5y:  projectPortfolio(baselineSave, netWorth, 5),
    projection_10y: projectPortfolio(baselineSave, netWorth, 10),
  }

  // Baseline FIRE years (for tradeoff notes)
  const baselineFireResult = fireNumber
    ? computeFireDate(netWorth, fireNumber, baselineSave, returnRate, currentAge)
    : null

  // ── Build each plan ──
  function buildPlan(
    rate: number,
    planType: 'steady' | 'recommended' | 'accelerate'
  ): PlanDetail {
    const monthlySave  = roundMoney(income * (rate / 100))
    const monthlySpend = roundMoney(income - monthlySave)
    const flexibleSpend = roundMoney(Math.max(0, monthlySpend - fixed))
    const extra         = roundMoney(monthlySave - baseline.monthly_save)
    const compressionPct = flexible > 0
      ? round2((1 - flexibleSpend / flexible) * 100)
      : 0

    const p1y  = projectPortfolio(monthlySave, netWorth, 1)
    const p5y  = projectPortfolio(monthlySave, netWorth, 5)
    const p10y = projectPortfolio(monthlySave, netWorth, 10)

    // FIRE date projection for this plan
    let officialFireDate: string | null  = null
    let officialFireAge: number | null   = null
    let fireYearsVsBaseline: number | null = null

    if (fireNumber) {
      const fireResult = computeFireDate(netWorth, fireNumber, monthlySave, returnRate, currentAge)
      officialFireDate = fireResult.fireDate !== 'Unknown' ? fireResult.fireDate : null
      officialFireAge  = fireResult.fireAge

      if (baselineFireResult && baselineFireResult.yearsRemaining < 99) {
        fireYearsVsBaseline = baselineFireResult.yearsRemaining - fireResult.yearsRemaining
      }
    }

    const tradeoffNote = buildTradeoffNote(
      extra,
      baselineFireResult?.yearsRemaining ?? 99,
      fireNumber
        ? computeFireDate(netWorth, fireNumber, monthlySave, returnRate, currentAge).yearsRemaining
        : 99
    )

    return {
      savings_rate:              roundRate(rate),
      monthly_save:              monthlySave,
      monthly_spend:             monthlySpend,
      spending_ceiling_monthly:  monthlySpend,     // alias
      flexible_spend:            flexibleSpend,
      extra_per_month:           extra,
      flexible_compression_pct:  compressionPct,
      projection_1y:             p1y,
      projection_5y:             p5y,
      projection_10y:            p10y,
      gain_vs_baseline_10y:      round2(p10y - baseline.projection_10y),
      feasibility:               classifyFeasibility(rate, currentRate),
      status:                    determineStatus(monthlySave, currentRate),
      official_fire_date:        officialFireDate,
      official_fire_age:         officialFireAge,
      fire_years_vs_baseline:    fireYearsVsBaseline,
      tradeoff_note:             tradeoffNote,
      positioning_copy:          getPositioningCopy(planType),
    }
  }

  const plans = {
    steady:      buildPlan(steadyRate,      'steady'),
    recommended: buildPlan(recommendedRate, 'recommended'),
    accelerate:  buildPlan(accelerateRate,  'accelerate'),
  }

  const critical = plans.accelerate.status === 'deficit'

  return { baseline, plans, maxPossibleRate, critical }
}

// ── Handler ───────────────────────────────────────────────────

serve(async (req) => {
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

    const body: GeneratePlansRequest = await req.json()

    if (!body.avg_monthly_income || body.avg_monthly_income <= 0) {
      return errorResponse(400, 'INVALID_INPUT', 'avg_monthly_income must be > 0')
    }

    // Resolve net worth, age, and fire_number — client values take priority
    let netWorth   = body.current_net_worth
    let currentAge = body.current_age
    let fireNumber = body.fire_number

    // Fetch profile + active goal in parallel when any field is missing
    if (
      netWorth   == null ||
      currentAge == null ||
      fireNumber == null
    ) {
      const [profileResult, goalResult] = await Promise.all([
        supabase
          .from('user_profiles')
          .select('age, current_net_worth, plaid_net_worth')
          .eq('user_id', user.id)
          .maybeSingle(),
        supabase
          .from('fire_goals')
          .select('fire_number, retirement_spending_monthly, withdrawal_rate_assumption, return_assumption, current_age')
          .eq('user_id', user.id)
          .eq('is_active', true)
          .maybeSingle(),
      ])

      if (netWorth == null) {
        netWorth = profileResult.data?.plaid_net_worth
          ?? profileResult.data?.current_net_worth
          ?? 0
      }
      if (currentAge == null) {
        currentAge = profileResult.data?.age ?? goalResult.data?.current_age ?? null
      }
      if (fireNumber == null) {
        const goal = goalResult.data
        if (goal?.fire_number > 0) {
          fireNumber = goal.fire_number
        } else if (goal?.retirement_spending_monthly > 0) {
          fireNumber = computeFireNumber(
            goal.retirement_spending_monthly,
            goal.withdrawal_rate_assumption ?? 0.04
          )
        } else if (body.retirement_spending_monthly) {
          fireNumber = computeFireNumber(body.retirement_spending_monthly)
        }
      }
    }

    const returnRate = body.return_assumption ?? REAL_ANNUAL_RETURN

    const { baseline, plans, maxPossibleRate, critical } = generateAllPlans({
      current_savings_rate:   body.current_savings_rate,
      avg_monthly_income:     body.avg_monthly_income,
      avg_monthly_savings:    body.avg_monthly_savings,
      avg_monthly_fixed:      body.avg_monthly_fixed,
      avg_monthly_flexible:   body.avg_monthly_flexible,
      current_net_worth:      netWorth    ?? 0,
      current_age:            currentAge  ?? 30,
      fire_number:            fireNumber  ?? null,
      return_assumption:      returnRate,
    })

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          baseline,
          plans,
          user_tier:       getUserTier(body.current_savings_rate),
          max_possible_rate: round2(maxPossibleRate),
          critical,
          current_net_worth: netWorth    ?? 0,
          current_age:       currentAge  ?? null,
          fire_number:       fireNumber  ?? null,
          assumptions: {
            nominal_return: NOMINAL_ANNUAL_RETURN,
            inflation:      INFLATION_RATE,
            real_return:    returnRate,
          },
        },
        meta: { timestamp: new Date().toISOString(), user_id: user.id },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in generate-plans:', error)
    return errorResponse(500, 'INTERNAL_SERVER_ERROR', error.message)
  }
})

function errorResponse(status: number, code: string, message: string): Response {
  return new Response(
    JSON.stringify({ success: false, error: { code, message } }),
    { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}
