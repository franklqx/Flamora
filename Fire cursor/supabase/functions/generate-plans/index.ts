// supabase/functions/generate-plans/index.ts
//
// V3 Budget Module — plan generation handler.
//
// This handler is intentionally thin:
//   - auth / profile-goal lookup / request validation
//   - translate request + stored goal/profile into a PlanInput
//   - delegate ALL budget-plan math to `_shared/plan-generator.ts`
//
// Contract target (per budget-plan-budget-plan-gentle-blossom.md):
//   - returns dynamic 1–3 plans, not fixed steady/recommended/accelerate cards
//   - primary plan truthfully reports exact / closest_near / closest_far / already_fire
//   - exposes custom slider availability and bounds for Step 5
//   - keeps AI out of every numeric decision

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { ASSUMPTIONS } from '../_shared/fire-assumptions.ts'
import {
  computeBudgetPlans,
  deriveCustomSliderRange,
  type PlanInput,
  type PlanOutput,
} from '../_shared/plan-generator.ts'
import {
  fetchActiveInvestmentAccountTotal,
  pickStartingPortfolio,
} from '../_shared/starting-portfolio.ts'

interface GeneratePlansRequest {
  current_savings_rate?: number            // legacy percent (0..100), retained for compatibility only
  avg_monthly_income?: number
  avg_monthly_savings?: number
  avg_monthly_expenses?: number
  avg_monthly_fixed?: number               // legacy alias / fallback for essential_floor
  avg_monthly_flexible?: number            // legacy alias / fallback for avg_wants
  current_net_worth?: number
  starting_portfolio_balance?: number
  starting_portfolio_source?: string
  current_age?: number
  fire_number?: number
  retirement_spending_monthly?: number
  target_retirement_age?: number
  return_assumption?: number
  withdrawal_rate?: number
  essential_floor?: number
  avg_wants?: number
  account_ids?: string[]
  month?: string
}

interface GoalRow {
  fire_number: number | null
  retirement_spending_monthly: number | null
  target_retirement_age: number | null
  withdrawal_rate_assumption: number | null
  return_assumption: number | null
  current_age: number | null
}

interface ProfileRow {
  age: number | null
  current_net_worth: number | null
  plaid_net_worth: number | null
  starting_portfolio_balance: number | null
  starting_portfolio_source: string | null
}

function round2(value: number): number {
  return Math.round(value * 100) / 100
}

function round4(value: number): number {
  return Math.round(value * 10000) / 10000
}

function errorResponse(status: number, code: string, message: string): Response {
  return new Response(
    JSON.stringify({ success: false, error: { code, message } }),
    { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
  )
}

function serializePlan(plan: PlanOutput) {
  return {
    feasibility: plan.feasibility,
    anchor: plan.anchor,
    label: plan.label,
    reason: plan.reason,
    limit_reason: plan.limitReason,
    monthly_save: round2(plan.monthlySave),
    monthly_budget: round2(plan.monthlySpendCeiling),
    committed_spend_ceiling: round2(plan.monthlySpendCeiling),
    savings_rate: round4(plan.savingsRate),
    fire_number: round2(plan.fireNumber),
    fire_age_months: Number.isFinite(plan.fireAgeMonths) ? round2(plan.fireAgeMonths) : null,
    projected_fire_age: plan.fireAge,
    fire_age_years: plan.fireAgeYears,
    gap_months: Number.isFinite(plan.gapMonths) ? round2(plan.gapMonths) : null,
    gap_years: plan.gapYears,
    headline: plan.headline,
    sub: plan.sub,
    badge: plan.badge,
    cta: plan.cta,
  }
}

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return errorResponse(401, 'UNAUTHORIZED', 'Missing Authorization header')

    const supabaseAuth = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    )

    const { data: { user }, error: authError } = await supabaseAuth.auth.getUser()
    if (authError || !user) return errorResponse(401, 'UNAUTHORIZED', 'Invalid token')

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const body: GeneratePlansRequest = await req.json()

    const shouldFetchProfileForPortfolio =
      body.starting_portfolio_source !== 'explicit_zero' &&
      ((body.starting_portfolio_balance ?? body.current_net_worth ?? 0) <= 0)
    const needsProfile =
      (body.starting_portfolio_balance == null && body.current_net_worth == null) ||
      body.current_age == null ||
      shouldFetchProfileForPortfolio
    const needsGoal =
      body.target_retirement_age == null ||
      body.retirement_spending_monthly == null ||
      body.fire_number == null ||
      body.withdrawal_rate == null

    let profile: ProfileRow | null = null
    let goal: GoalRow | null = null

    if (needsProfile || needsGoal) {
      const [profileResult, goalResult] = await Promise.all([
        supabase
          .from('user_profiles')
          .select('age, current_net_worth, plaid_net_worth, starting_portfolio_balance, starting_portfolio_source')
          .eq('user_id', user.id)
          .maybeSingle(),
        supabase
          .from('fire_goals')
          .select('fire_number, retirement_spending_monthly, target_retirement_age, withdrawal_rate_assumption, return_assumption, current_age')
          .eq('user_id', user.id)
          .eq('is_active', true)
          .maybeSingle(),
      ])

      profile = (profileResult.data as ProfileRow | null) ?? null
      goal = (goalResult.data as GoalRow | null) ?? null
    }

    const avgIncome = body.avg_monthly_income ?? null
    if (avgIncome == null || avgIncome < 0) {
      return errorResponse(400, 'INVALID_INPUT', 'avg_monthly_income must be provided and >= 0')
    }

    const avgSpend = body.avg_monthly_expenses
      ?? (
        body.avg_monthly_fixed != null && body.avg_monthly_flexible != null
          ? body.avg_monthly_fixed + body.avg_monthly_flexible
          : null
      )
      ?? (
        body.avg_monthly_savings != null
          ? Math.max(0, avgIncome - body.avg_monthly_savings)
          : null
      )

    if (avgSpend == null || avgSpend < 0) {
      return errorResponse(
        400,
        'INVALID_INPUT',
        'Need avg_monthly_expenses, or both avg_monthly_fixed + avg_monthly_flexible, or avg_monthly_savings to derive spend baseline',
      )
    }

    const currentAge = body.current_age
      ?? profile?.age
      ?? goal?.current_age
      ?? null
    if (currentAge == null || currentAge <= 0) {
      return errorResponse(400, 'MISSING_CURRENT_AGE', 'current_age is required (or must exist on profile/goal)')
    }

    const targetAge = body.target_retirement_age
      ?? goal?.target_retirement_age
      ?? null
    if (targetAge == null || targetAge <= 0) {
      return errorResponse(400, 'MISSING_TARGET_AGE', 'target_retirement_age is required for V3 plan generation')
    }

    let startingPortfolio = pickStartingPortfolio({
      bodyStartingPortfolioBalance: body.starting_portfolio_balance,
      bodyStartingPortfolioSource: body.starting_portfolio_source,
      bodyCurrentNetWorth: body.current_net_worth,
      profile,
    })

    if (
      body.starting_portfolio_source !== 'explicit_zero' &&
      startingPortfolio.balance <= 0
    ) {
      const connectedInvestmentTotal = await fetchActiveInvestmentAccountTotal(supabase, user.id)
      startingPortfolio = pickStartingPortfolio({
        bodyStartingPortfolioBalance: body.starting_portfolio_balance,
        bodyStartingPortfolioSource: body.starting_portfolio_source,
        bodyCurrentNetWorth: body.current_net_worth,
        profile,
        connectedInvestmentTotal,
      })
    }

    if (startingPortfolio.shouldPersistProfile) {
      await supabase
        .from('user_profiles')
        .update({
          starting_portfolio_balance: round2(startingPortfolio.balance),
          starting_portfolio_source: startingPortfolio.source,
          starting_portfolio_updated_at: new Date().toISOString(),
        })
        .eq('user_id', user.id)
    }

    const startingPortfolioBalance = startingPortfolio.balance
    const startingPortfolioSource = startingPortfolio.source

    const essentialFloor = body.essential_floor
      ?? body.avg_monthly_fixed
      ?? 0

    const avgWants = body.avg_wants
      ?? body.avg_monthly_flexible
      ?? 0

    const retirementSpending = body.retirement_spending_monthly
      ?? goal?.retirement_spending_monthly
      ?? avgSpend

    const withdrawalRate = body.withdrawal_rate
      ?? goal?.withdrawal_rate_assumption
      ?? ASSUMPTIONS.WITHDRAWAL_RATE

    const fireNumber = body.fire_number
      ?? goal?.fire_number
      ?? ((retirementSpending * 12) / withdrawalRate)

    const realReturn = body.return_assumption
      ?? goal?.return_assumption
      ?? ASSUMPTIONS.REAL_ANNUAL_RETURN

    const input: PlanInput = {
      targetAge,
      currentAge,
      netWorth: startingPortfolioBalance,
      avgIncome,
      avgSpend,
      essentialFloor,
      avgWants,
      retirementSpending,
      currentMonthlySave: body.avg_monthly_savings ?? (avgIncome - avgSpend),
      withdrawalRate,
      realReturn,
    }

    const plans = computeBudgetPlans(input)
    const primary = plans[0]
    const customSlider = deriveCustomSliderRange(input, primary)

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          plans: plans.map(serializePlan),
          plan_count: plans.length,
          primary_plan_label: primary.label,
          current_net_worth: round2(startingPortfolioBalance),
          starting_portfolio_balance: round2(startingPortfolioBalance),
          starting_portfolio_source: startingPortfolioSource,
          current_age: currentAge,
          target_retirement_age: targetAge,
          retirement_spending_monthly: round2(retirementSpending),
          fire_number: round2(fireNumber),
          custom_slider: {
            is_available: customSlider.isAvailable,
            min_monthly_save: customSlider.minMonthlySave != null ? round2(customSlider.minMonthlySave) : null,
            max_monthly_save: customSlider.maxMonthlySave != null ? round2(customSlider.maxMonthlySave) : null,
          },
          assumptions: {
            real_return: realReturn,
            withdrawal_rate: withdrawalRate,
          },
          // Transitional aliases so later phases can migrate incrementally without
          // re-deriving these values client-side.
          committed_defaults: {
            committed_plan_label: primary.label,
            committed_monthly_save: round2(primary.monthlySave),
            committed_savings_rate: round4(primary.savingsRate),
            committed_spend_ceiling: round2(primary.monthlySpendCeiling),
          },
        },
        meta: {
          timestamp: new Date().toISOString(),
          user_id: user.id,
          account_ids: body.account_ids ?? null,
          month: body.month ?? null,
        },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (error) {
    console.error('Error in generate-plans:', error)
    const message = error instanceof Error ? error.message : 'Unknown error'
    return errorResponse(500, 'INTERNAL_SERVER_ERROR', message)
  }
})
