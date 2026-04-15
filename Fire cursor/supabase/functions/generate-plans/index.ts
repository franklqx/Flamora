// supabase/functions/generate-plans/index.ts
//
// V3 Budget Module — Plan generation (goal-driven)
//
// New primary flow (S2-1):
//   When target_retirement_age + retirement_spending_monthly are available,
//   the server runs FIRECalculator.adjustGoal() and derives plan rates from
//   its paths (plan_a / plan_b / recommended / current_path).
//
//   Mapping with fallback chain:
//     steady       = plan_b ?? current_path
//     recommended  = recommended ?? plan_a ?? plan_b ?? current_path
//     accelerate   = plan_a ?? recommended ?? current_path
//
//   Phase 0 special case: plan_b / recommended are null; accelerate is computed
//   as "retire 5 years earlier than target" to preserve three distinct cards.
//
//   Phase 2: accelerate card carries warning=true so iOS can show the warning.
//
// Backward-compat flow:
//   If target_retirement_age is missing (old client / pre-S1 users), falls back
//   to the legacy flexible-compression rate calculation.
//
// Trust boundary: the server does NOT accept client-computed feasibility data.
// Per-plan FIRE date / tradeoff / positioning copy are produced via existing
// helpers (fire-math.ts), unchanged from v2.

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import {
  computeFireDate,
  computeFireNumber,
  getPositioningCopy,
  buildTradeoffNote,
} from '../_shared/fire-math.ts'
import { ASSUMPTIONS } from '../_shared/fire-assumptions.ts'
import { FIRECalculator, type AdjustGoalResult, type PathDetail } from '../_shared/fire-calculator.ts'

// ── Global assumptions ────────────────────────────────────────
const NOMINAL_ANNUAL_RETURN = ASSUMPTIONS.NOMINAL_ANNUAL_RETURN   // display projections
const REAL_ANNUAL_RETURN    = ASSUMPTIONS.REAL_ANNUAL_RETURN       // feasibility / required savings
const INFLATION_RATE        = ASSUMPTIONS.INFLATION_RATE
const MONTHLY_REAL_RATE     = REAL_ANNUAL_RETURN / 12

// Flexible compression ratios (legacy fallback path only)
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
  // Goal fields (client may override server's active goal for Step-4-to-Step-5 drift safety)
  fire_number?: number
  retirement_spending_monthly?: number
  target_retirement_age?: number
  return_assumption?: number    // override (default: REAL_ANNUAL_RETURN)
  // Audit / scoping only — server does not recompute stats from these
  account_ids?: string[]
  month?: string
}

interface PlanDetail {
  savings_rate: number
  monthly_save: number
  monthly_spend: number
  spending_ceiling_monthly: number
  flexible_spend: number
  extra_per_month: number
  flexible_compression_pct: number
  projection_1y: number
  projection_5y: number
  projection_10y: number
  gain_vs_baseline_10y: number
  feasibility: 'easy' | 'moderate' | 'challenging' | 'extreme'
  status: 'on_track' | 'breakeven' | 'deficit'
  official_fire_date: string | null
  official_fire_age: number | null
  fire_years_vs_baseline: number | null
  tradeoff_note: string
  positioning_copy: string
  // NEW (S2-1): warning flag for Phase 2 accelerate card
  warning?: boolean
}

// ── Core math helpers ─────────────────────────────────────────

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

/**
 * Required monthly savings to hit fireNumber in exactly N years (real return).
 * Used by Phase 0 accelerate synthesis.
 */
function requiredMonthlySavingsForYears(
  currentNW: number,
  fireNumber: number,
  years: number
): number {
  if (years <= 0) return Math.max(0, fireNumber - currentNW)
  const months = years * 12
  const fvPV = currentNW * Math.pow(1 + MONTHLY_REAL_RATE, months)
  const remaining = fireNumber - fvPV
  if (remaining <= 0) return 0
  const factor = (Math.pow(1 + MONTHLY_REAL_RATE, months) - 1) / MONTHLY_REAL_RATE
  return remaining / factor
}

// ── Legacy (compression-based) rate calculation ───────────────

interface GenerateInput {
  current_savings_rate: number
  avg_monthly_income: number
  avg_monthly_savings: number
  avg_monthly_fixed: number
  avg_monthly_flexible: number
  current_net_worth: number
  current_age: number
  fire_number: number | null
  return_assumption: number
}

function legacyRates(input: GenerateInput) {
  const {
    current_savings_rate: currentRate,
    avg_monthly_income: income,
    avg_monthly_savings: currentSavings,
    avg_monthly_fixed: fixed,
    avg_monthly_flexible: flexible,
  } = input

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

  return { steadyRate, recommendedRate, accelerateRate, maxPossibleRate }
}

// ── Goal-driven rate calculation (FIRECalculator paths) ───────

interface GoalDrivenRates {
  steadyRate: number
  recommendedRate: number
  accelerateRate: number
  steadyAge: number | null
  recommendedAge: number | null
  accelerateAge: number | null
  maxPossibleRate: number
  phase: 0 | 1 | 2
  phaseSub: string
  strategy: AdjustGoalResult['strategy']
  warningOnAccelerate: boolean
}

function goalDrivenRates(
  calc: AdjustGoalResult,
  input: GenerateInput,
  targetRetirementAge: number,
  fireNumber: number
): GoalDrivenRates {
  const currentPath = calc.current_path
  const income = input.avg_monthly_income
  const maxPossibleRate = income > 0 ? ((income - input.avg_monthly_fixed) / income) * 100 : 0

  let steadyRate: number, steadyAge: number | null
  let recommendedRate: number, recommendedAge: number | null
  let accelerateRate: number, accelerateAge: number | null

  if (calc.phase === 0) {
    // Already on track — plan_b / recommended are null.
    // Steady = current path, Recommended = plan_a (exactly hit target age),
    // Accelerate = retire 5 years earlier than target (synthesized).
    const planA = calc.plan_a ?? currentPath
    steadyRate = currentPath.savings_rate
    steadyAge = currentPath.retirement_age
    recommendedRate = planA.savings_rate
    recommendedAge = planA.retirement_age

    const earlierAge = Math.max(input.current_age + 1, targetRetirementAge - 5)
    const earlierYears = Math.max(earlierAge - input.current_age, 1)
    const earlierSavings = requiredMonthlySavingsForYears(input.current_net_worth, fireNumber, earlierYears)
    accelerateRate = income > 0 ? (earlierSavings / income) * 100 : 0
    accelerateAge = earlierAge
  } else {
    // Phase 1 / 2: fallback chain guarantees three paths even if calc has nulls.
    const steady = calc.plan_b ?? currentPath
    const recommended = calc.recommended ?? calc.plan_a ?? calc.plan_b ?? currentPath
    const accelerate = calc.plan_a ?? calc.recommended ?? currentPath

    steadyRate = steady.savings_rate
    steadyAge = steady.retirement_age
    recommendedRate = recommended.savings_rate
    recommendedAge = recommended.retirement_age
    accelerateRate = accelerate.savings_rate
    accelerateAge = accelerate.retirement_age
  }

  // Enforce strict ordering (steady ≤ recommended ≤ accelerate).
  // Small floor deltas prevent cards collapsing into each other visually.
  if (recommendedRate < steadyRate) recommendedRate = steadyRate
  if (accelerateRate  < recommendedRate) accelerateRate = recommendedRate

  return {
    steadyRate,
    recommendedRate,
    accelerateRate,
    steadyAge,
    recommendedAge,
    accelerateAge,
    maxPossibleRate,
    phase: calc.phase,
    phaseSub: calc.phase_sub,
    strategy: calc.strategy,
    warningOnAccelerate: calc.phase === 2,
  }
}

// ── Unified plan builder ──────────────────────────────────────

function generateAllPlans(
  input: GenerateInput,
  goalDriven: GoalDrivenRates | null
) {
  const {
    current_savings_rate: currentRate,
    avg_monthly_income: income,
    avg_monthly_savings: currentSavings,
    avg_monthly_fixed: fixed,
    avg_monthly_flexible: flexible,
    current_net_worth: netWorth,
    current_age: currentAge,
    fire_number: fireNumber,
    return_assumption: returnRate,
  } = input

  let steadyRate: number, recommendedRate: number, accelerateRate: number
  let maxPossibleRate: number
  let steadyAgeOverride: number | null = null
  let recommendedAgeOverride: number | null = null
  let accelerateAgeOverride: number | null = null
  let warningOnAccelerate = false

  if (goalDriven) {
    steadyRate = goalDriven.steadyRate
    recommendedRate = goalDriven.recommendedRate
    accelerateRate = goalDriven.accelerateRate
    maxPossibleRate = goalDriven.maxPossibleRate
    steadyAgeOverride = goalDriven.steadyAge
    recommendedAgeOverride = goalDriven.recommendedAge
    accelerateAgeOverride = goalDriven.accelerateAge
    warningOnAccelerate = goalDriven.warningOnAccelerate
  } else {
    const legacy = legacyRates(input)
    steadyRate = legacy.steadyRate
    recommendedRate = legacy.recommendedRate
    accelerateRate = legacy.accelerateRate
    maxPossibleRate = legacy.maxPossibleRate
  }

  // Baseline (used for projections + tradeoff notes)
  const baselineSave = roundMoney(Math.max(0, currentSavings))
  const baseline = {
    savings_rate:   roundRate(currentRate),
    monthly_save:   baselineSave,
    projection_1y:  projectPortfolio(baselineSave, netWorth, 1),
    projection_5y:  projectPortfolio(baselineSave, netWorth, 5),
    projection_10y: projectPortfolio(baselineSave, netWorth, 10),
  }

  const baselineFireResult = fireNumber
    ? computeFireDate(netWorth, fireNumber, baselineSave, returnRate, currentAge)
    : null

  function buildPlan(
    rate: number,
    planType: 'steady' | 'recommended' | 'accelerate',
    fireAgeOverride: number | null,
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

    let officialFireDate: string | null  = null
    let officialFireAge: number | null   = null
    let fireYearsVsBaseline: number | null = null

    if (fireNumber) {
      const fireResult = computeFireDate(netWorth, fireNumber, monthlySave, returnRate, currentAge)
      officialFireDate = fireResult.fireDate !== 'Unknown' ? fireResult.fireDate : null
      // Path age from FIRECalculator wins when available (authoritative source for goal-driven mode).
      officialFireAge  = fireAgeOverride ?? fireResult.fireAge

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
      spending_ceiling_monthly:  monthlySpend,
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
    steady:      buildPlan(steadyRate,      'steady',      steadyAgeOverride),
    recommended: buildPlan(recommendedRate, 'recommended', recommendedAgeOverride),
    accelerate:  {
      ...buildPlan(accelerateRate, 'accelerate', accelerateAgeOverride),
      ...(warningOnAccelerate ? { warning: true } : {}),
    },
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

    // Resolve profile + active goal when any goal-related field is missing.
    let netWorth             = body.current_net_worth
    let currentAge           = body.current_age
    let fireNumber           = body.fire_number
    let retirementSpending   = body.retirement_spending_monthly
    let targetRetirementAge  = body.target_retirement_age

    const needsProfile = netWorth == null || currentAge == null
    const needsGoal = fireNumber == null || retirementSpending == null || targetRetirementAge == null

    if (needsProfile || needsGoal) {
      const [profileResult, goalResult] = await Promise.all([
        supabase
          .from('user_profiles')
          .select('age, current_net_worth, plaid_net_worth')
          .eq('user_id', user.id)
          .maybeSingle(),
        supabase
          .from('fire_goals')
          .select('fire_number, retirement_spending_monthly, target_retirement_age, withdrawal_rate_assumption, return_assumption, current_age')
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

      const goal = goalResult.data
      if (retirementSpending == null) {
        retirementSpending = goal?.retirement_spending_monthly ?? undefined
      }
      if (targetRetirementAge == null) {
        targetRetirementAge = goal?.target_retirement_age ?? undefined
      }
      if (fireNumber == null) {
        if (goal?.fire_number && goal.fire_number > 0) {
          fireNumber = goal.fire_number
        } else if (retirementSpending && retirementSpending > 0) {
          fireNumber = computeFireNumber(
            retirementSpending,
            goal?.withdrawal_rate_assumption ?? ASSUMPTIONS.WITHDRAWAL_RATE
          )
        }
      }
    }

    const returnRate = body.return_assumption ?? REAL_ANNUAL_RETURN
    const resolvedNetWorth   = netWorth ?? 0
    const resolvedCurrentAge = currentAge ?? 30
    const resolvedFireNumber = fireNumber ?? null

    // Decide goal-driven vs legacy mode.
    // Goal-driven requires: target age, retirement spending, income, current age, fire number.
    const canRunFeasibility =
      targetRetirementAge != null &&
      targetRetirementAge > 0 &&
      retirementSpending != null &&
      retirementSpending > 0 &&
      resolvedFireNumber != null &&
      resolvedFireNumber > 0 &&
      body.avg_monthly_income > 0 &&
      currentAge != null &&
      targetRetirementAge > currentAge

    let goalDriven: GoalDrivenRates | null = null

    if (canRunFeasibility) {
      const calculator = new FIRECalculator()
      const currentMonthlyExpenses = (body.avg_monthly_fixed ?? 0) + (body.avg_monthly_flexible ?? 0)
      const calc = calculator.adjustGoal({
        monthlyIncome: body.avg_monthly_income,
        currentAge: resolvedCurrentAge,
        targetRetirementAge: targetRetirementAge!,
        desiredMonthlyExpenses: retirementSpending!,
        currentNetWorth: resolvedNetWorth,
        currentMonthlyExpenses,
      })
      goalDriven = goalDrivenRates(calc, {
        current_savings_rate:   body.current_savings_rate,
        avg_monthly_income:     body.avg_monthly_income,
        avg_monthly_savings:    body.avg_monthly_savings,
        avg_monthly_fixed:      body.avg_monthly_fixed,
        avg_monthly_flexible:   body.avg_monthly_flexible,
        current_net_worth:      resolvedNetWorth,
        current_age:            resolvedCurrentAge,
        fire_number:            resolvedFireNumber,
        return_assumption:      returnRate,
      }, targetRetirementAge!, resolvedFireNumber!)
    }

    const { baseline, plans, maxPossibleRate, critical } = generateAllPlans({
      current_savings_rate:   body.current_savings_rate,
      avg_monthly_income:     body.avg_monthly_income,
      avg_monthly_savings:    body.avg_monthly_savings,
      avg_monthly_fixed:      body.avg_monthly_fixed,
      avg_monthly_flexible:   body.avg_monthly_flexible,
      current_net_worth:      resolvedNetWorth,
      current_age:            resolvedCurrentAge,
      fire_number:            resolvedFireNumber,
      return_assumption:      returnRate,
    }, goalDriven)

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          baseline,
          plans,
          user_tier:         getUserTier(body.current_savings_rate),
          max_possible_rate: round2(maxPossibleRate),
          critical,
          current_net_worth: resolvedNetWorth,
          current_age:       currentAge ?? null,
          fire_number:       resolvedFireNumber,
          // NEW (S2-1): feasibility context for iOS banner / warnings
          phase:             goalDriven?.phase ?? null,
          phase_sub:         goalDriven?.phaseSub ?? null,
          strategy:          goalDriven?.strategy ?? null,
          goal_driven:       goalDriven != null,
          assumptions: {
            nominal_return: NOMINAL_ANNUAL_RETURN,
            inflation:      INFLATION_RATE,
            real_return:    returnRate,
          },
        },
        meta: {
          timestamp: new Date().toISOString(),
          user_id: user.id,
          account_ids: body.account_ids ?? null,
          month: body.month ?? null,
        },
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
