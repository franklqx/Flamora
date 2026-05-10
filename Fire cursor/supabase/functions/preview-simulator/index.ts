// supabase/functions/preview-simulator/index.ts
//
// Powers both demo and real sandbox simulator.
// NEVER writes to any official state.
//
// Modes:
//   demo             — uses provided inputs only, no real user data access
//   official_preview — loads active plan + fire goal as anchors; applies overrides on top
//
// Response always contains:
//   - official_path (empty array in demo mode)
//   - adjusted_path (the sandbox projection)
//   - delta_months (adjusted - official; negative = faster)

import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import {
  computeFireDate,
  computeFireNumber,
} from '../_shared/fire-math.ts'
import { ASSUMPTIONS } from '../_shared/fire-assumptions.ts'
import {
  generateSimulatorLifecycle,
  SIMULATOR_LIFECYCLE_END_AGE,
} from '../_shared/simulator-lifecycle.ts'

// ── Types ─────────────────────────────────────────────────────

interface PreviewSimulatorRequest {
  mode: 'demo' | 'official_preview'

  // Official plan anchors (used in official_preview; optional in demo)
  official_savings_monthly?: number
  official_retirement_spending?: number
  official_net_worth?: number
  official_age?: number

  // Sandbox overrides (applied on top of official anchors in official_preview mode;
  // used directly in demo mode)
  sandbox_savings_monthly?: number
  sandbox_retirement_spending?: number
  sandbox_return_rate?: number       // annual; default 0.07
  sandbox_inflation_rate?: number    // informational only for now
  sandbox_withdrawal_rate?: number   // default 0.04
  sandbox_target_age?: number        // optional — only for display in sandbox
}

interface DataPoint {
  year: number
  net_worth: number
}

interface LifecyclePoint extends DataPoint {
  age: number
  phase: string
}

// ── Handler ───────────────────────────────────────────────────

Deno.serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return errorResponse(401, 'UNAUTHORIZED', 'Missing Authorization header')

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)
    if (authError || !user) return errorResponse(401, 'UNAUTHORIZED', 'Invalid token')

    const body: PreviewSimulatorRequest = await req.json()
    const mode = body.mode ?? 'demo'

    // Simulator lifecycle uses today's dollars, so use real return after inflation.
    const DEFAULT_RETURN_RATE = ASSUMPTIONS.REAL_ANNUAL_RETURN
    const DEFAULT_WITHDRAWAL  = ASSUMPTIONS.WITHDRAWAL_RATE

    // ── Resolve official anchors ──────────────────────────────
    let officialSavings:  number | null = body.official_savings_monthly ?? null
    let officialSpending: number | null = body.official_retirement_spending ?? null
    let officialNetWorth: number | null = body.official_net_worth ?? null
    let officialAge:      number | null = body.official_age ?? null
    let officialFireNumber: number | null = null

    if (mode === 'official_preview') {
      // Load real data when official anchors are missing
      const anyMissing = officialSavings == null || officialSpending == null || officialNetWorth == null

      if (anyMissing) {
        const [activePlanResult, goalResult, profileResult] = await Promise.all([
          supabase
            .from('active_plans')
            .select('savings_target_monthly')
            .eq('user_id', user.id)
            .eq('is_active', true)
            .maybeSingle(),
          supabase
            .from('fire_goals')
            .select('retirement_spending_monthly, fire_number, withdrawal_rate_assumption, return_assumption, current_age')
            .eq('user_id', user.id)
            .eq('is_active', true)
            .maybeSingle(),
          supabase
            .from('user_profiles')
            .select('starting_portfolio_balance, plaid_net_worth, current_net_worth, age')
            .eq('user_id', user.id)
            .maybeSingle(),
        ])

        if (officialSavings == null) {
          officialSavings = activePlanResult.data?.savings_target_monthly ?? 0
        }
        if (officialSpending == null) {
          officialSpending = goalResult.data?.retirement_spending_monthly ?? null
        }
        if (officialNetWorth == null) {
          officialNetWorth = profileResult.data?.starting_portfolio_balance
            ?? profileResult.data?.plaid_net_worth
            ?? profileResult.data?.current_net_worth
            ?? 0
        }
        if (officialAge == null) {
          officialAge = profileResult.data?.age ?? goalResult.data?.current_age ?? null
        }
        if (goalResult.data?.fire_number > 0) {
          officialFireNumber = goalResult.data.fire_number
        } else if (officialSpending) {
          const wr = goalResult.data?.withdrawal_rate_assumption ?? DEFAULT_WITHDRAWAL
          officialFireNumber = computeFireNumber(officialSpending, wr)
        }
      } else if (officialSpending) {
        officialFireNumber = computeFireNumber(officialSpending, body.sandbox_withdrawal_rate ?? DEFAULT_WITHDRAWAL)
      }
    } else {
      // Demo mode: compute fire_number from provided spending (or use a demo default)
      const demoSpending = body.official_retirement_spending ?? body.sandbox_retirement_spending ?? 5000
      const demoNetWorth = body.official_net_worth ?? 50000
      const demoWithdrawal = body.sandbox_withdrawal_rate ?? DEFAULT_WITHDRAWAL

      officialSpending = demoSpending
      officialNetWorth = demoNetWorth
      officialFireNumber = computeFireNumber(demoSpending, demoWithdrawal)
      officialSavings = body.official_savings_monthly ?? 0
    }

    // ── Resolve sandbox overrides ─────────────────────────────
    const sandboxSavings  = body.sandbox_savings_monthly     ?? officialSavings  ?? 0
    const sandboxSpending = body.sandbox_retirement_spending ?? officialSpending ?? (officialFireNumber ? officialFireNumber * 0.04 / 12 : 5000)
    const sandboxReturn   = body.sandbox_return_rate         ?? DEFAULT_RETURN_RATE
    const sandboxWithdraw = body.sandbox_withdrawal_rate     ?? DEFAULT_WITHDRAWAL
    const sandboxFireNumber = computeFireNumber(sandboxSpending, sandboxWithdraw)

    const netWorth = officialNetWorth ?? 0
    const currentAge = officialAge ?? 33

    // ── Compute official FIRE date (empty in demo) ────────────
    let officialFireDate: string | null = null
    let officialFireAge:  number | null = null
    let officialFireMonths: number | null = null

    if (mode === 'official_preview' && officialFireNumber && officialSavings != null) {
      const r = computeFireDate(netWorth, officialFireNumber, officialSavings, DEFAULT_RETURN_RATE, currentAge)
      officialFireDate  = r.fireDate !== 'Unknown' ? r.fireDate : null
      officialFireAge   = r.fireAge
      officialFireMonths = r.yearsRemaining * 12
    }

    // ── Compute sandbox FIRE date ─────────────────────────────
    const sandboxResult = computeFireDate(netWorth, sandboxFireNumber, sandboxSavings, sandboxReturn, currentAge)
    const sandboxFireDate = sandboxResult.fireDate !== 'Unknown' ? sandboxResult.fireDate : null
    const sandboxFireMonths = sandboxResult.yearsRemaining * 12

    // delta: negative = faster, positive = slower
    const deltaMonths = officialFireMonths != null
      ? sandboxFireMonths - officialFireMonths
      : 0
    const deltaYears  = Math.round((deltaMonths / 12) * 10) / 10

    // ── Generate lifecycle series ─────────────────────────────
    const officialLifecycle = mode === 'official_preview' && officialSavings != null && officialFireNumber
      ? generateSimulatorLifecycle({
          currentAge,
          currentNetWorth: netWorth,
          monthlySavings: officialSavings,
          annualRealReturn: DEFAULT_RETURN_RATE,
          retirementSpendingMonthly: officialSpending ?? sandboxSpending,
          fireNumber: officialFireNumber,
          endAge: SIMULATOR_LIFECYCLE_END_AGE,
        })
      : { path: [] as LifecyclePoint[], portfolio_depletion_age: null }

    const adjustedLifecycle = generateSimulatorLifecycle({
      currentAge,
      currentNetWorth: netWorth,
      monthlySavings: sandboxSavings,
      annualRealReturn: sandboxReturn,
      retirementSpendingMonthly: sandboxSpending,
      fireNumber: sandboxFireNumber,
      endAge: SIMULATOR_LIFECYCLE_END_AGE,
    })

    // Legacy chart fields now mirror lifecycle values for backward compatibility.
    const officialPath: DataPoint[] = officialLifecycle.path.map(({ year, net_worth }) => ({ year, net_worth }))
    const adjustedPath: DataPoint[] = adjustedLifecycle.path.map(({ year, net_worth }) => ({ year, net_worth }))

    // ── Return ────────────────────────────────────────────────
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          mode,

          official_fire_date:   officialFireDate,
          official_fire_age:    officialFireAge,
          official_fire_number: mode === 'official_preview' ? officialFireNumber : null,

          preview_fire_date:   sandboxFireDate,
          preview_fire_age:    sandboxResult.fireAge,
          preview_fire_number: sandboxFireNumber,

          delta_months: deltaMonths,
          delta_years:  deltaYears,

          official_path: officialPath,
          adjusted_path: adjustedPath,
          official_lifecycle_path: officialLifecycle.path,
          adjusted_lifecycle_path: adjustedLifecycle.path,
          portfolio_depletion_age: adjustedLifecycle.portfolio_depletion_age,
          lifecycle_end_age: SIMULATOR_LIFECYCLE_END_AGE,
          projection_basis: 'real_dollars',

          // Echo back the effective inputs used (useful for UI display)
          effective_inputs: {
            savings_monthly:     sandboxSavings,
            retirement_spending: sandboxSpending,
            return_rate:         sandboxReturn,
            withdrawal_rate:     sandboxWithdraw,
            net_worth:           netWorth,
            current_age:         currentAge,
          },
        },
        meta: { timestamp: new Date().toISOString(), user_id: user.id },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in preview-simulator:', error)
    return errorResponse(500, 'INTERNAL_SERVER_ERROR', error.message)
  }
})

function errorResponse(status: number, code: string, message: string): Response {
  return new Response(
    JSON.stringify({ success: false, error: { code, message } }),
    { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}
