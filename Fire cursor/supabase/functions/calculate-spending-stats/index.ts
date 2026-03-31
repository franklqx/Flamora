// supabase/functions/calculate-spending-stats/index.ts
//
// V2 Budget Module — Step 1
// Analyses Plaid transaction data to compute:
//   - avg monthly income, expenses, savings, savings rate
//   - fixed vs flexible expense classification
//   - flexible sub-category breakdown
//   - monthly breakdown for diagnosis charts
//
// Replaces: calculate-avg-spending (V1)

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// ============================================================
// Types
// ============================================================

interface RequestBody {
  months?: number // default: 6
  account_ids?: string[] // optional: only analyze transactions from these plaid_account IDs
}

interface FixedExpenseItem {
  name: string
  pfc_detailed: string | null
  avg_monthly_amount: number
  months_appeared: number
  variance_pct: number
  is_always_fixed: boolean
}

interface FlexibleBreakdownItem {
  subcategory: string
  avg_monthly_amount: number
  share_of_flexible: number
  transaction_count: number
}

interface MonthlyBreakdownItem {
  month: string
  income: number
  fixed: number
  flexible: number
  savings: number
}

// ============================================================
// Classification rules
// ============================================================

const ALWAYS_FIXED_PFC_PRIMARY = new Set([
  'RENT_AND_UTILITIES',
  'LOAN_PAYMENTS',
])

const ALWAYS_FIXED_PFC_DETAILED_PREFIXES = [
  'RENT_',
  'UTILITIES_',
  'INSURANCE_',
  'LOAN_PAYMENTS_',
  'MORTGAGE_',
]

const ALWAYS_FLEXIBLE_PFC_PRIMARY = new Set([
  'FOOD_AND_DRINK',
  'ENTERTAINMENT',
  'GENERAL_MERCHANDISE',
  'TRAVEL',
])

const ALWAYS_FLEXIBLE_SUBCATEGORIES = new Set([
  'dining_out',
  'shopping',
  'entertainment',
  'groceries',
])

// ============================================================
// Helper functions
// ============================================================

function isAlwaysFixed(pfcPrimary: string | null, pfcDetailed: string | null): boolean {
  if (pfcPrimary && ALWAYS_FIXED_PFC_PRIMARY.has(pfcPrimary)) return true
  if (pfcDetailed) {
    for (const prefix of ALWAYS_FIXED_PFC_DETAILED_PREFIXES) {
      if (pfcDetailed.startsWith(prefix)) return true
    }
  }
  return false
}

function isAlwaysFlexible(pfcPrimary: string | null, flamoraSubcategory: string | null): boolean {
  if (pfcPrimary && ALWAYS_FLEXIBLE_PFC_PRIMARY.has(pfcPrimary)) return true
  if (flamoraSubcategory && ALWAYS_FLEXIBLE_SUBCATEGORIES.has(flamoraSubcategory)) return true
  return false
}

function calculateMedian(values: number[]): number {
  if (values.length === 0) return 0
  const sorted = [...values].sort((a, b) => a - b)
  const mid = Math.floor(sorted.length / 2)
  return sorted.length % 2 !== 0
    ? sorted[mid]
    : (sorted[mid - 1] + sorted[mid]) / 2
}

function getMonthKey(dateStr: string): string {
  return dateStr.substring(0, 7) // "2026-01-15" → "2026-01"
}

function round2(value: number): number {
  return Math.round(value * 100) / 100
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
    let body: RequestBody = {}
    try { body = await req.json() } catch { /* empty body OK */ }

    const months = body.months || 6
    const startDate = new Date()
    startDate.setMonth(startDate.getMonth() - months)
    const startDateStr = startDate.toISOString().split('T')[0]

    // ============================================================
    // 3. Get user profile (for fallback income)
    // ============================================================
    const { data: profile } = await supabase
      .from('user_profiles')
      .select('monthly_income, current_monthly_expenses, has_linked_bank')
      .eq('user_id', user.id)
      .single()

    const manualIncome = profile?.monthly_income || 0
    const manualExpenses = profile?.current_monthly_expenses || 0

    // ============================================================
    // 4. Check for user classification overrides
    // ============================================================
    const { data: userOverrides } = await supabase
      .from('spending_classifications')
      .select('payee_or_category, classification')
      .eq('user_id', user.id)

    const overrideMap = new Map<string, string>()
    if (userOverrides) {
      for (const o of userOverrides) {
        overrideMap.set(o.payee_or_category, o.classification)
      }
    }

    // ============================================================
    // 5. Fetch all expense transactions
    // ============================================================
    let expenseQuery = supabase
      .from('transactions')
      .select('amount, date, name, merchant_name, pfc_primary, pfc_detailed, flamora_category, flamora_subcategory')
      .eq('user_id', user.id)
      .eq('pending', false)
      .in('flamora_category', ['needs', 'wants'])
      .gt('amount', 0)
      .gte('date', startDateStr)
      .order('date', { ascending: true })

    // If specific accounts requested, filter by plaid_account_id
    if (body.account_ids && body.account_ids.length > 0) {
      expenseQuery = expenseQuery.in('plaid_account_id', body.account_ids)
    }

    const { data: expenseTxns, error: expError } = await expenseQuery

    if (expError) {
      console.error('Error fetching expense transactions:', expError)
      return new Response(
        JSON.stringify({ success: false, error: { code: 'QUERY_ERROR', message: expError.message } }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ============================================================
    // 6. Fetch income transactions
    // ============================================================
    let incomeQuery = supabase
      .from('transactions')
      .select('amount, date, pfc_primary')
      .eq('user_id', user.id)
      .eq('pending', false)
      .lt('amount', 0)  // Plaid: income = negative amount
      .gte('date', startDateStr)

    // Also check for pfc_primary = 'INCOME' with positive amounts (some Plaid setups)
    let incomeAltQuery = supabase
      .from('transactions')
      .select('amount, date, pfc_primary')
      .eq('user_id', user.id)
      .eq('pending', false)
      .eq('pfc_primary', 'INCOME')
      .gt('amount', 0)
      .gte('date', startDateStr)

    if (body.account_ids && body.account_ids.length > 0) {
      incomeQuery = incomeQuery.in('plaid_account_id', body.account_ids)
      incomeAltQuery = incomeAltQuery.in('plaid_account_id', body.account_ids)
    }

    const { data: incomeTxns } = await incomeQuery
    const { data: incomeTxnsAlt } = await incomeAltQuery

    // ============================================================
    // 7. Handle no-data fallback
    // ============================================================
    if (!expenseTxns || expenseTxns.length === 0) {
      // No Plaid expense data — use onboarding estimates
      const estimatedFixed = manualExpenses * 0.40
      const estimatedFlexible = manualExpenses * 0.60
      const estimatedSavings = manualIncome - manualExpenses
      const estimatedRate = manualIncome > 0 ? (estimatedSavings / manualIncome) * 100 : 0

      return new Response(
        JSON.stringify({
          success: true,
          data: {
            avg_monthly_income: round2(manualIncome),
            avg_monthly_expenses: round2(manualExpenses),
            avg_monthly_savings: round2(estimatedSavings),
            current_savings_rate: round2(estimatedRate),
            avg_monthly_fixed: round2(estimatedFixed),
            avg_monthly_flexible: round2(estimatedFlexible),
            fixed_expenses: [],
            flexible_breakdown: [],
            income_source: 'manual',
            months_analyzed: 0,
            data_quality: 'limited',
            total_transactions: 0,
            monthly_breakdown: [],
          },
          meta: { timestamp: new Date().toISOString(), user_id: user.id },
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ============================================================
    // 8. Determine months analyzed
    // ============================================================
    const allExpenseMonths = new Set(expenseTxns.map(t => getMonthKey(t.date)))
    const monthsAnalyzed = allExpenseMonths.size || 1
    const minFixedFrequency = monthsAnalyzed < 3 ? 2 : 3

    // ============================================================
    // 9. Compute income
    // ============================================================
    let totalIncome = 0

    // From negative-amount transactions
    if (incomeTxns && incomeTxns.length > 0) {
      totalIncome += incomeTxns.reduce((sum, t) => sum + Math.abs(t.amount), 0)
    }

    // From INCOME-category positive-amount transactions
    if (incomeTxnsAlt && incomeTxnsAlt.length > 0) {
      totalIncome += incomeTxnsAlt.reduce((sum, t) => sum + t.amount, 0)
    }

    let avgMonthlyIncome = totalIncome / monthsAnalyzed
    let incomeSource: 'plaid' | 'manual' = 'plaid'

    // Fallback to manual if Plaid income is 0 or very low
    if (avgMonthlyIncome < 100 && manualIncome > 0) {
      avgMonthlyIncome = manualIncome
      incomeSource = 'manual'
    }

    if (avgMonthlyIncome <= 0) {
      return new Response(
        JSON.stringify({ success: false, error: { code: 'NO_INCOME', message: 'Could not detect monthly income. Please set it in your profile.' } }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ============================================================
    // 10. Group expenses by payee for fixed detection
    // ============================================================
    interface PayeeGroup {
      name: string
      pfcPrimary: string | null
      pfcDetailed: string | null
      flamoraSubcategory: string | null
      amounts: number[]
      months: Set<string>
      totalAmount: number
      txnCount: number
    }

    const payeeGroups = new Map<string, PayeeGroup>()

    for (const txn of expenseTxns) {
      // Use merchant_name if available, otherwise fall back to pfc_detailed
      const key = txn.merchant_name || txn.pfc_detailed || txn.name || 'unknown'

      if (!payeeGroups.has(key)) {
        payeeGroups.set(key, {
          name: key,
          pfcPrimary: txn.pfc_primary,
          pfcDetailed: txn.pfc_detailed,
          flamoraSubcategory: txn.flamora_subcategory,
          amounts: [],
          months: new Set(),
          totalAmount: 0,
          txnCount: 0,
        })
      }

      const group = payeeGroups.get(key)!
      group.amounts.push(txn.amount)
      group.months.add(getMonthKey(txn.date))
      group.totalAmount += txn.amount
      group.txnCount++
    }

    // ============================================================
    // 11. Classify each payee group as fixed or flexible
    // ============================================================
    const fixedExpenses: FixedExpenseItem[] = []
    let totalFixed = 0
    let totalExpenses = 0

    // Track flexible by subcategory
    const flexibleBySubcategory = new Map<string, { total: number; count: number }>()

    for (const [key, group] of payeeGroups) {
      const monthlyAmounts: number[] = []
      // Calculate average monthly amount for this payee
      for (const month of allExpenseMonths) {
        const monthTxns = expenseTxns.filter(
          t => (t.merchant_name || t.pfc_detailed || t.name || 'unknown') === key
            && getMonthKey(t.date) === month
        )
        if (monthTxns.length > 0) {
          monthlyAmounts.push(monthTxns.reduce((s, t) => s + t.amount, 0))
        }
      }

      const median = calculateMedian(monthlyAmounts)
      const maxVariance = monthlyAmounts.length > 0
        ? Math.max(...monthlyAmounts.map(a => median > 0 ? Math.abs(a - median) / median : 0))
        : 0
      const avgMonthlyAmount = group.totalAmount / monthsAnalyzed

      totalExpenses += group.totalAmount

      // Check user override first
      if (overrideMap.has(key)) {
        const override = overrideMap.get(key)!
        if (override === 'fixed') {
          fixedExpenses.push({
            name: group.name,
            pfc_detailed: group.pfcDetailed,
            avg_monthly_amount: round2(avgMonthlyAmount),
            months_appeared: group.months.size,
            variance_pct: round2(maxVariance),
            is_always_fixed: false,
          })
          totalFixed += avgMonthlyAmount * monthsAnalyzed
        } else {
          // User said flexible
          const subcat = group.flamoraSubcategory || 'other_flexible'
          const existing = flexibleBySubcategory.get(subcat) || { total: 0, count: 0 }
          existing.total += group.totalAmount
          existing.count += group.txnCount
          flexibleBySubcategory.set(subcat, existing)
        }
        continue
      }

      // Auto-classification
      const alwaysFixed = isAlwaysFixed(group.pfcPrimary, group.pfcDetailed)
      const alwaysFlexible = isAlwaysFlexible(group.pfcPrimary, group.flamoraSubcategory)

      if (alwaysFlexible) {
        const subcat = group.flamoraSubcategory || 'other_flexible'
        const existing = flexibleBySubcategory.get(subcat) || { total: 0, count: 0 }
        existing.total += group.totalAmount
        existing.count += group.txnCount
        flexibleBySubcategory.set(subcat, existing)
      } else if (alwaysFixed) {
        fixedExpenses.push({
          name: group.name,
          pfc_detailed: group.pfcDetailed,
          avg_monthly_amount: round2(avgMonthlyAmount),
          months_appeared: group.months.size,
          variance_pct: round2(maxVariance),
          is_always_fixed: true,
        })
        totalFixed += avgMonthlyAmount * monthsAnalyzed
      } else if (group.months.size >= minFixedFrequency && maxVariance <= 0.20) {
        // Recurring + stable amount → fixed
        fixedExpenses.push({
          name: group.name,
          pfc_detailed: group.pfcDetailed,
          avg_monthly_amount: round2(avgMonthlyAmount),
          months_appeared: group.months.size,
          variance_pct: round2(maxVariance),
          is_always_fixed: false,
        })
        totalFixed += avgMonthlyAmount * monthsAnalyzed
      } else {
        // Default: flexible
        const subcat = group.flamoraSubcategory || 'other_flexible'
        const existing = flexibleBySubcategory.get(subcat) || { total: 0, count: 0 }
        existing.total += group.totalAmount
        existing.count += group.txnCount
        flexibleBySubcategory.set(subcat, existing)
      }
    }

    // ============================================================
    // 12. Calculate averages
    // ============================================================
    const avgMonthlyExpenses = totalExpenses / monthsAnalyzed
    const avgMonthlyFixed = totalFixed / monthsAnalyzed / monthsAnalyzed * monthsAnalyzed  // simplify
    const avgMonthlyFixedCalc = fixedExpenses.reduce((sum, f) => sum + f.avg_monthly_amount, 0)
    const avgMonthlyFlexible = avgMonthlyExpenses - avgMonthlyFixedCalc
    const avgMonthlySavings = avgMonthlyIncome - avgMonthlyExpenses
    const currentSavingsRate = avgMonthlyIncome > 0
      ? (avgMonthlySavings / avgMonthlyIncome) * 100
      : 0

    // ============================================================
    // 13. Build flexible breakdown
    // ============================================================
    const totalFlexibleSpending = Array.from(flexibleBySubcategory.values())
      .reduce((sum, v) => sum + v.total, 0)

    const flexibleBreakdown: FlexibleBreakdownItem[] = Array.from(flexibleBySubcategory.entries())
      .map(([subcat, data]) => ({
        subcategory: subcat,
        avg_monthly_amount: round2(data.total / monthsAnalyzed),
        share_of_flexible: totalFlexibleSpending > 0
          ? round2(data.total / totalFlexibleSpending)
          : 0,
        transaction_count: data.count,
      }))
      .sort((a, b) => b.avg_monthly_amount - a.avg_monthly_amount)

    // ============================================================
    // 14. Build monthly breakdown (for charts)
    // ============================================================
    // Build income by month
    const incomeByMonth = new Map<string, number>()
    if (incomeTxns) {
      for (const t of incomeTxns) {
        const mk = getMonthKey(t.date)
        incomeByMonth.set(mk, (incomeByMonth.get(mk) || 0) + Math.abs(t.amount))
      }
    }
    if (incomeTxnsAlt) {
      for (const t of incomeTxnsAlt) {
        const mk = getMonthKey(t.date)
        incomeByMonth.set(mk, (incomeByMonth.get(mk) || 0) + t.amount)
      }
    }

    // Build fixed/flexible by month
    const fixedNames = new Set(fixedExpenses.map(f => f.name))

    const monthlyBreakdown: MonthlyBreakdownItem[] = Array.from(allExpenseMonths)
      .sort()
      .map(month => {
        const monthTxns = expenseTxns.filter(t => getMonthKey(t.date) === month)
        let fixedTotal = 0
        let flexibleTotal = 0

        for (const t of monthTxns) {
          const key = t.merchant_name || t.pfc_detailed || t.name || 'unknown'
          if (fixedNames.has(key)) {
            fixedTotal += t.amount
          } else {
            flexibleTotal += t.amount
          }
        }

        const monthIncome = incomeByMonth.get(month) || avgMonthlyIncome
        const monthSavings = monthIncome - fixedTotal - flexibleTotal

        return {
          month,
          income: round2(monthIncome),
          fixed: round2(fixedTotal),
          flexible: round2(flexibleTotal),
          savings: round2(monthSavings),
        }
      })

    // ============================================================
    // 15. Return
    // ============================================================
    const dataQuality = monthsAnalyzed >= 3 ? 'good' : 'limited'

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          avg_monthly_income: round2(avgMonthlyIncome),
          avg_monthly_expenses: round2(avgMonthlyExpenses),
          avg_monthly_savings: round2(avgMonthlySavings),
          current_savings_rate: round2(currentSavingsRate),

          avg_monthly_fixed: round2(avgMonthlyFixedCalc),
          avg_monthly_flexible: round2(Math.max(0, avgMonthlyFlexible)),

          fixed_expenses: fixedExpenses.sort((a, b) => b.avg_monthly_amount - a.avg_monthly_amount),
          flexible_breakdown: flexibleBreakdown,

          income_source: incomeSource,
          months_analyzed: monthsAnalyzed,
          data_quality: dataQuality,
          total_transactions: expenseTxns.length,

          monthly_breakdown: monthlyBreakdown,
        },
        meta: { timestamp: new Date().toISOString(), user_id: user.id },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in calculate-spending-stats:', error)
    return new Response(
      JSON.stringify({ success: false, error: { code: 'INTERNAL_SERVER_ERROR', message: error.message || 'An unexpected error occurred' } }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
