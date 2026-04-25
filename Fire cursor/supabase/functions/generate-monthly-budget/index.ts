// supabase/functions/generate-monthly-budget/index.ts
//
// UPDATED: JWT auth, upsert (no more 409 on existing), accepts custom ratios,
// uses Plaid real spending data when available, ratio rounding fix

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface GenerateBudgetRequest {
  month?: string           // 'YYYY-MM-01', defaults to current month
  needs_ratio?: number     // Custom ratio override (user adjusted)
  wants_ratio?: number
  savings_ratio?: number
  source?: 'setup' | 'manual'  // setup = initial flow, manual = later adjustment
  // Budget Setup V2 传入的字段
  savings_rate?: number
  fixed_budget?: number
  flexible_budget?: number
  selected_plan?: string
  needs_budget?: number
  wants_budget?: number
  savings_budget?: number
  committed_savings_rate?: number
  committed_monthly_save?: number
  committed_spend_ceiling?: number
  committed_plan_label?: string
  snapshot_avg_income?: number
  snapshot_avg_spend?: number
  snapshot_net_worth?: number
  snapshot_starting_portfolio_balance?: number
  snapshot_starting_portfolio_source?: string
  snapshot_essential_floor?: number
  snapshot_date?: string
  retirement_spending_monthly?: number
  // Per-category budget amounts; keys are canonical TransactionCategoryCatalog ids
  category_budgets?: Record<string, number>
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
        JSON.stringify({ success: false, error: { code: 'UNAUTHORIZED', message: 'Invalid or expired token' } }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Service role client for data operations (bypasses RLS)
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // ============================================================
    // 2. Parse request
    // ============================================================
    let body: GenerateBudgetRequest = {}
    try {
      body = await req.json()
    } catch {
      // Empty body is OK — we'll auto-generate
    }

    const month = body.month || getFirstDayOfMonth(new Date())
    const hasCustomRatios = body.needs_ratio !== undefined &&
                            body.wants_ratio !== undefined &&
                            body.savings_ratio !== undefined

    // ============================================================
    // 3. Get user profile
    // ============================================================
    const { data: profile, error: profileError } = await supabase
      .from('user_profiles')
      .select('monthly_income, current_monthly_expenses, has_linked_bank')
      .eq('user_id', user.id)
      .single()

    if (profileError || !profile) {
      return new Response(
        JSON.stringify({ success: false, error: { code: 'PROFILE_NOT_FOUND', message: 'User profile not found' } }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const monthlyIncome = profile.monthly_income || 0
    // Budget Setup 已算出 needs/wants/savings 金额时，不应因 user_profiles.monthly_income 未填而拒绝保存。
    const setupBudgetSum =
      (body.needs_budget ?? 0) + (body.wants_budget ?? 0) + (body.savings_budget ?? 0)
    const hasSetupBudgetAmounts =
      body.source === 'setup' &&
      body.needs_budget !== undefined &&
      body.wants_budget !== undefined &&
      body.savings_budget !== undefined &&
      setupBudgetSum > 0

    if (monthlyIncome <= 0 && !hasSetupBudgetAmounts) {
      return new Response(
        JSON.stringify({ success: false, error: { code: 'NO_INCOME', message: 'Monthly income must be greater than 0' } }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ============================================================
    // 4. Determine ratios
    // ============================================================
    let needsRatio: number, wantsRatio: number, savingsRatio: number
    let isCustom = false

    if (hasCustomRatios) {
      // User provided specific ratios (from budget setup UI or manual adjustment)
      needsRatio = body.needs_ratio!
      wantsRatio = body.wants_ratio!
      savingsRatio = body.savings_ratio!
      isCustom = body.source === 'manual'

      // Validate sum ≈ 100
      const total = needsRatio + wantsRatio + savingsRatio
      if (Math.abs(total - 100) > 0.5) {
        return new Response(
          JSON.stringify({ success: false, error: { code: 'INVALID_RATIOS', message: `Ratios must sum to 100 (got ${total.toFixed(2)})` } }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      // Normalize to exactly 100
      const normalizedTotal = needsRatio + wantsRatio + savingsRatio
      if (normalizedTotal !== 100) {
        const diff = 100 - normalizedTotal
        savingsRatio += diff // Absorb rounding error into savings
      }

    } else {
      // Auto-generate ratios based on FIRE goal + real spending data

      // Get FIRE goal for savings rate
      const { data: fireGoal } = await supabase
        .from('fire_goals')
        .select('required_savings_rate')
        .eq('user_id', user.id)
        .eq('is_active', true)
        .single()

      const targetSavingsRate = fireGoal?.required_savings_rate || 20 // Default 20% if no goal

      // Get real Plaid spending data if available
      let realNeedsTotal = 0
      let realWantsTotal = 0
      let hasPlaidData = false

      if (profile.has_linked_bank) {
        // Fetch last 3 months of spending to get ratio
        const threeMonthsAgo = new Date()
        threeMonthsAgo.setMonth(threeMonthsAgo.getMonth() - 3)
        const startDate = threeMonthsAgo.toISOString().split('T')[0]

        const { data: needsTxns } = await supabase
          .from('transactions')
          .select('amount')
          .eq('user_id', user.id)
          .eq('flamora_category', 'needs')
          .eq('pending', false)
          .gte('date', startDate)

        const { data: wantsTxns } = await supabase
          .from('transactions')
          .select('amount')
          .eq('user_id', user.id)
          .eq('flamora_category', 'wants')
          .eq('pending', false)
          .gte('date', startDate)

        realNeedsTotal = (needsTxns || []).reduce((sum, t) => sum + Math.max(0, t.amount), 0)
        realWantsTotal = (wantsTxns || []).reduce((sum, t) => sum + Math.max(0, t.amount), 0)
        hasPlaidData = (realNeedsTotal + realWantsTotal) > 0
      }

      // Calculate ratios
      savingsRatio = Math.min(targetSavingsRate, 60) // Cap at 60%
      const remainingPct = 100 - savingsRatio

      if (hasPlaidData) {
        // Use real Plaid spending proportions
        const totalSpending = realNeedsTotal + realWantsTotal
        const needsShare = realNeedsTotal / totalSpending  // e.g. 0.61
        const wantsShare = realWantsTotal / totalSpending  // e.g. 0.39
        needsRatio = parseFloat((remainingPct * needsShare).toFixed(2))
        wantsRatio = parseFloat((remainingPct * wantsShare).toFixed(2))
      } else {
        // Fallback: estimate 60% needs, 40% wants of remaining
        needsRatio = parseFloat((remainingPct * 0.60).toFixed(2))
        wantsRatio = parseFloat((remainingPct * 0.40).toFixed(2))
      }

      // Ensure ratios sum to exactly 100
      const diff = 100 - (needsRatio + wantsRatio + savingsRatio)
      if (Math.abs(diff) > 0.001) {
        wantsRatio = parseFloat((wantsRatio + diff).toFixed(2))
      }
    }

    // ============================================================
    // 5. Calculate dollar amounts
    // ============================================================
    const needsBudget = parseFloat((monthlyIncome * needsRatio / 100).toFixed(2))
    const wantsBudget = parseFloat((monthlyIncome * wantsRatio / 100).toFixed(2))
    const savingsBudget = parseFloat((monthlyIncome * savingsRatio / 100).toFixed(2))

    // ============================================================
    // 6. Upsert into budgets table
    // ============================================================
    // 当 source 为 'setup' 或 'manual' 且客户端传了具体金额时，直接使用客户端的值。
    // 'manual' = cashflow_edit 路径，用户显式编辑了金额，不应被 profile.monthly_income × ratio 覆盖。
    const clientProvidesBudget =
      (body.source === 'setup' || body.source === 'manual') &&
      body.needs_budget !== undefined &&
      body.wants_budget !== undefined &&
      body.savings_budget !== undefined
    const finalNeedsBudget   = clientProvidesBudget ? body.needs_budget!   : needsBudget
    const finalWantsBudget   = clientProvidesBudget ? body.wants_budget!   : wantsBudget
    const finalSavingsBudget = clientProvidesBudget ? body.savings_budget! : savingsBudget

    const { data: budget, error: upsertError } = await supabase
      .from('budgets')
      .upsert({
        user_id: user.id,
        month: month,
        needs_budget: finalNeedsBudget,
        wants_budget: finalWantsBudget,
        savings_budget: finalSavingsBudget,
        needs_ratio: needsRatio,
        wants_ratio: wantsRatio,
        savings_ratio: savingsRatio,
        savings_rate: body.savings_rate ?? null,
        fixed_budget: body.fixed_budget ?? null,
        flexible_budget: body.flexible_budget ?? null,
        selected_plan: body.selected_plan ?? null,
        committed_savings_rate: body.committed_savings_rate ?? null,
        committed_monthly_save: body.committed_monthly_save ?? null,
        committed_spend_ceiling: body.committed_spend_ceiling ?? null,
        committed_plan_label: body.committed_plan_label ?? null,
        snapshot_avg_income: body.snapshot_avg_income ?? null,
        snapshot_avg_spend: body.snapshot_avg_spend ?? null,
        snapshot_net_worth: body.snapshot_net_worth ?? null,
        snapshot_starting_portfolio_balance: body.snapshot_starting_portfolio_balance ?? null,
        snapshot_starting_portfolio_source: body.snapshot_starting_portfolio_source ?? null,
        snapshot_essential_floor: body.snapshot_essential_floor ?? null,
        snapshot_date: body.snapshot_date ?? null,
        retirement_spending_monthly: body.retirement_spending_monthly ?? null,
        is_custom: isCustom,
        category_budgets: body.category_budgets ?? {},
        updated_at: new Date().toISOString(),
      }, {
        onConflict: 'user_id,month',
      })
      .select()
      .single()

    if (upsertError) {
      console.error('Error upserting budget:', upsertError)
      return new Response(
        JSON.stringify({ success: false, error: { code: 'UPSERT_ERROR', message: 'Failed to save budget', details: upsertError.message } }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ============================================================
    // 7. Return
    // ============================================================
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          budget_id: budget.id,
          month: budget.month,
          needs_budget: budget.needs_budget,
          wants_budget: budget.wants_budget,
          savings_budget: budget.savings_budget,
          needs_ratio: budget.needs_ratio,
          wants_ratio: budget.wants_ratio,
          savings_ratio: budget.savings_ratio,
          savings_rate: budget.savings_rate,
          fixed_budget: budget.fixed_budget,
          flexible_budget: budget.flexible_budget,
          selected_plan: budget.selected_plan,
          committed_savings_rate: budget.committed_savings_rate,
          committed_monthly_save: budget.committed_monthly_save,
          committed_spend_ceiling: budget.committed_spend_ceiling,
          committed_plan_label: budget.committed_plan_label,
          snapshot_avg_income: budget.snapshot_avg_income,
          snapshot_avg_spend: budget.snapshot_avg_spend,
          snapshot_net_worth: budget.snapshot_net_worth,
          snapshot_starting_portfolio_balance: budget.snapshot_starting_portfolio_balance,
          snapshot_starting_portfolio_source: budget.snapshot_starting_portfolio_source,
          snapshot_essential_floor: budget.snapshot_essential_floor,
          snapshot_date: budget.snapshot_date,
          retirement_spending_monthly: budget.retirement_spending_monthly,
          is_custom: budget.is_custom,
          category_budgets: budget.category_budgets ?? {},
        },
        meta: {
          timestamp: new Date().toISOString(),
          user_id: user.id,
          source: body.source || 'auto',
        },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in generate-monthly-budget:', error)
    const message = error instanceof Error ? error.message : 'An unexpected error occurred'
    return new Response(
      JSON.stringify({ success: false, error: { code: 'INTERNAL_SERVER_ERROR', message } }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

function getFirstDayOfMonth(date: Date): string {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  return `${year}-${month}-01`
}
