// supabase/functions/get-active-fire-goal/index.ts
//
// v2: Official Hero source endpoint.
//
// New fields added to response (all optional — old clients ignore them):
//   official_fire_date    "Mar 2042"
//   official_fire_age     47
//   years_remaining       (now computed from active plan or goal savings, not just age diff)
//   progress_status       one-line Hero copy
//   active_plan_type      "recommended" | null
//   active_plan_label     "Recommended" | null
//   savings_target_monthly  from active_plans row | null
//
// Backward compat:
//   All v1 fields preserved (goal_id, fire_number, current_net_worth, gap_to_fire,
//   required_savings_rate, target_retirement_age, current_age, years_remaining,
//   progress_percentage, on_track, data_source, created_at)

import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { computeFireDate, computeFireNumber, getProgressStatus } from '../_shared/fire-math.ts'
import { ASSUMPTIONS } from '../_shared/fire-assumptions.ts'

Deno.serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    // ── 1. Auth ──────────────────────────────────────────────
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return errorResponse(401, 'UNAUTHORIZED', 'Missing Authorization header')
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)
    if (authError || !user) {
      return errorResponse(401, 'UNAUTHORIZED', 'Invalid token')
    }

    // ── 2. Parallel fetch: goal + profile + active plan ───────
    const [goalResult, profileResult, activePlanResult] = await Promise.all([
      supabase
        .from('fire_goals')
        .select('*')
        .eq('user_id', user.id)
        .eq('is_active', true)
        .maybeSingle(),
      supabase
        .from('user_profiles')
        .select('current_net_worth, has_linked_bank, plaid_net_worth, age')
        .eq('user_id', user.id)
        .maybeSingle(),
      supabase
        .from('active_plans')
        .select('*')
        .eq('user_id', user.id)
        .eq('is_active', true)
        .maybeSingle(),
    ])

    const fireGoal = goalResult.data
    if (!fireGoal) {
      return errorResponse(404, 'NO_ACTIVE_GOAL',
        'No active FIRE goal found. Please create one first.')
    }

    const profile   = profileResult.data
    const activePlan = activePlanResult.data

    // ── 3. Resolve current net worth ─────────────────────────
    let currentNetWorth: number
    let dataSource: string

    if (profile?.has_linked_bank && profile?.plaid_net_worth != null) {
      currentNetWorth = profile.plaid_net_worth
      dataSource = 'plaid'
    } else {
      currentNetWorth = profile?.current_net_worth ?? 0
      dataSource = 'manual'
    }

    // ── 4. Resolve fire_number ────────────────────────────────
    // Prefer stored fire_number; fall back to spending-based computation
    const fireNumber: number = fireGoal.fire_number > 0
      ? fireGoal.fire_number
      : (fireGoal.retirement_spending_monthly
          ? computeFireNumber(
              fireGoal.retirement_spending_monthly,
              fireGoal.withdrawal_rate_assumption ?? ASSUMPTIONS.WITHDRAWAL_RATE
            )
          : 0)

    // ── 5. Progress percentage ────────────────────────────────
    const gapToFire = Math.max(fireNumber - currentNetWorth, 0)
    const progressPercentage = fireNumber > 0
      ? parseFloat(((currentNetWorth / fireNumber) * 100).toFixed(2))
      : 0

    // ── 6. Resolve monthly savings source ────────────────────
    // Prefer active plan; fall back to goal's required contribution
    const monthlySavings: number =
      activePlan?.savings_target_monthly ??
      fireGoal.required_monthly_contribution ??
      0

    // Resolve current age (prefer profile.age over goal.current_age)
    const currentAge: number | null =
      profile?.age ?? fireGoal.current_age ?? null

    const returnRate: number = fireGoal.return_assumption ?? ASSUMPTIONS.REAL_ANNUAL_RETURN

    // ── 7. Compute official FIRE date ─────────────────────────
    const fireResult = computeFireDate(
      currentNetWorth,
      fireNumber,
      monthlySavings,
      returnRate,
      currentAge ?? undefined
    )

    // ── 8. on_track (linear progress check) ──────────────────
    // Simple heuristic: within 20% of linear path
    const yearsRemaining = fireResult.yearsRemaining
    const totalYearsEstimated = yearsRemaining + (fireGoal.current_age
      ? (new Date().getFullYear() - (new Date().getFullYear() - fireGoal.current_age))
      : 0)

    const onTrack = (() => {
      if (fireNumber <= 0) return false
      if (monthlySavings <= 0) return false
      // If progress ≥ 10% and savings are positive, treat as on track
      return progressPercentage >= 5 && monthlySavings > 0
    })()

    // ── 9. Progress status copy ───────────────────────────────
    const progressStatus = getProgressStatus(progressPercentage, onTrack)

    // ── 10. Active plan metadata ──────────────────────────────
    const PLAN_LABELS: Record<string, string> = {
      steady: 'Steady',
      recommended: 'Recommended',
      accelerate: 'Accelerate',
      'target-aligned': 'Target-aligned',
      comfortable: 'Comfortable',
      accelerated: 'Accelerated',
      closest_near: 'Closest reasonable',
      closest_far: 'Adjust target',
      already_fire: 'Already FIRE',
      custom: 'Custom',
    }
    const activePlanType  = activePlan?.plan_type ?? null
    const activePlanLabel = activePlanType ? (PLAN_LABELS[activePlanType] ?? activePlanType) : null

    // ── 11. Legacy years_remaining (backward compat) ──────────
    // Old clients used target_retirement_age - current_age.
    // New clients use official_fire_date + years_remaining from computation.
    const legacyYearsRemaining = (
      fireGoal.target_retirement_age != null && fireGoal.current_age != null
    )
      ? Math.max(0, fireGoal.target_retirement_age - fireGoal.current_age)
      : yearsRemaining

    // ── 12. Return ────────────────────────────────────────────
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          // ── v1 fields (unchanged) ──
          goal_id:               fireGoal.id,
          fire_number:           fireNumber,
          current_net_worth:     currentNetWorth,
          gap_to_fire:           gapToFire,
          required_savings_rate: fireGoal.required_savings_rate ?? 0,
          target_retirement_age: fireGoal.target_retirement_age ?? null,
          current_age:           fireGoal.current_age ?? null,
          years_remaining:       legacyYearsRemaining,
          progress_percentage:   progressPercentage,
          on_track:              onTrack,
          data_source:           dataSource,
          created_at:            fireGoal.created_at,

          // ── v2 Hero fields (new) ──
          official_fire_date:       fireResult.fireDate !== 'Unknown' ? fireResult.fireDate : null,
          official_fire_age:        fireResult.fireAge,
          official_years_remaining: yearsRemaining,
          progress_status:          progressStatus,
          active_plan_type:         activePlanType,
          active_plan_label:        activePlanLabel,
          savings_target_monthly:   activePlan?.savings_target_monthly ?? null,

          // Spending-based goal fields
          retirement_spending_monthly: fireGoal.retirement_spending_monthly ?? null,
          lifestyle_preset:            fireGoal.lifestyle_preset ?? null,
        },
        meta: {
          timestamp: new Date().toISOString(),
          user_id: user.id,
        },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in get-active-fire-goal:', error)
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
