// supabase/functions/generate-spending-plan/index.ts
//
// V2 Budget Module — Step 4
// Translates a selected plan's savings rate into a concrete monthly
// budget: fixed expenses (locked) + flexible sub-categories (suggested).
//
// Replaces: generate-monthly-budget (V1)

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// ============================================================
// Types
// ============================================================

interface FixedExpenseInput {
  name: string
  pfc_detailed: string | null
  monthly_amount: number
  is_user_corrected?: boolean
}

interface FlexibleCategoryInput {
  subcategory: string
  avg_monthly_amount: number
  share_of_flexible: number
}

interface GenerateSpendingPlanRequest {
  selected_plan_rate: number
  selected_plan_name: string          // "steady" | "recommended" | "accelerate" | "custom"
  avg_monthly_income: number
  fixed_expenses: FixedExpenseInput[]
  flexible_breakdown: FlexibleCategoryInput[]
  month: string                       // "YYYY-MM-01"
}

// ============================================================
// Helpers
// ============================================================

function round2(value: number): number {
  return Math.round(value * 100) / 100
}

function getFirstDayOfMonth(date: Date): string {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  return `${year}-${month}-01`
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
    // 2. Parse & validate request
    // ============================================================
    const body: GenerateSpendingPlanRequest = await req.json()

    if (!body.selected_plan_rate && body.selected_plan_rate !== 0) {
      return new Response(
        JSON.stringify({ success: false, error: { code: 'MISSING_FIELD', message: 'selected_plan_rate is required' } }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!body.avg_monthly_income || body.avg_monthly_income <= 0) {
      return new Response(
        JSON.stringify({ success: false, error: { code: 'INVALID_INPUT', message: 'avg_monthly_income must be > 0' } }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const month = body.month || getFirstDayOfMonth(new Date())
    const planRate = body.selected_plan_rate
    const planName = body.selected_plan_name || 'custom'
    const income = body.avg_monthly_income
    const fixedExpenses = body.fixed_expenses || []
    const flexibleBreakdown = body.flexible_breakdown || []

    // ============================================================
    // 3. Compute budget splits
    // ============================================================
    const totalSavings = round2(income * (planRate / 100))
    const totalSpend = round2(income - totalSavings)
    const totalFixed = round2(fixedExpenses.reduce((sum, f) => sum + f.monthly_amount, 0))
    const totalFlexible = round2(Math.max(0, totalSpend - totalFixed))

    const fixedExceedsBudget = totalSpend < totalFixed

    // ============================================================
    // 4. Distribute flexible budget across sub-categories
    // ============================================================
    const flexibleItems = flexibleBreakdown.map(cat => {
      const suggestedAmount = round2(cat.share_of_flexible * totalFlexible)
      const historicalAvg = cat.avg_monthly_amount
      const changePct = historicalAvg > 0
        ? round2(((suggestedAmount - historicalAvg) / historicalAvg) * 100)
        : 0

      return {
        subcategory: cat.subcategory,
        suggested_amount: suggestedAmount,
        historical_avg: round2(historicalAvg),
        change_pct: changePct,
      }
    }).sort((a, b) => b.suggested_amount - a.suggested_amount)

    // ============================================================
    // 5. Build fixed items for response
    // ============================================================
    const fixedItems = fixedExpenses.map(f => ({
      name: f.name,
      pfc_detailed: f.pfc_detailed,
      monthly_amount: round2(f.monthly_amount),
      is_user_corrected: f.is_user_corrected || false,
    })).sort((a, b) => b.monthly_amount - a.monthly_amount)

    // ============================================================
    // 6. Compute ratios for backward compatibility
    // ============================================================
    const savingsRatio = planRate
    const fixedRatio = income > 0 ? round2((totalFixed / income) * 100) : 0
    const flexibleRatio = income > 0 ? round2((totalFlexible / income) * 100) : 0

    // ============================================================
    // 7. Return spending plan (do NOT save yet — user confirms in Step 5)
    // ============================================================
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          month,
          plan_rate: planRate,
          plan_name: planName,

          total_income: round2(income),
          total_savings: totalSavings,
          total_spend: totalSpend,

          fixed_budget: {
            total: totalFixed,
            items: fixedItems,
          },

          flexible_budget: {
            total: totalFlexible,
            items: flexibleItems,
          },

          fixed_exceeds_budget: fixedExceedsBudget,

          // Backward-compatible ratios
          ratios: {
            savings: savingsRatio,
            fixed: fixedRatio,
            flexible: flexibleRatio,
          },
        },
        meta: { timestamp: new Date().toISOString(), user_id: user.id },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in generate-spending-plan:', error)
    return new Response(
      JSON.stringify({ success: false, error: { code: 'INTERNAL_SERVER_ERROR', message: error.message || 'An unexpected error occurred' } }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
