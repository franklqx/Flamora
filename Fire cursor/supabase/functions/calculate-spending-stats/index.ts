// supabase/functions/calculate-spending-stats/index.ts
//
// V2 Budget Module — Step 1
// Analyses Plaid transaction data to compute:
//   - avg monthly income, expenses, savings, savings rate
//   - needs vs wants budget classification
//   - wants category breakdown
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

const NEEDS_PFC_PRIMARY = new Set([
  'RENT_AND_UTILITIES',
  'LOAN_PAYMENTS',
  'INSURANCE',
  'MEDICAL',
  'TRANSPORTATION',
  'EDUCATION',
  'CHILDCARE',
  'GOVERNMENT_AND_NON_PROFIT',
])

const NEEDS_PFC_DETAILED_PREFIXES = [
  'RENT_',
  'UTILITIES_',
  'INSURANCE_',
  'LOAN_PAYMENTS_',
  'MORTGAGE_',
  'MEDICAL_',
  'TRANSPORTATION_',
]

const WANTS_PFC_PRIMARY = new Set([
  'FOOD_AND_DRINK',
  'ENTERTAINMENT',
  'GENERAL_MERCHANDISE',
  'TRAVEL',
  'RECREATION',
  'PERSONAL_CARE',
])

const WANTS_SUBCATEGORIES = new Set([
  'dining_out',
  'shopping',
  'entertainment',
  'subscription',
  'travel',
  'coffee',
  'bars',
  'food_delivery',
])

const NEEDS_SUBCATEGORIES = new Set([
  'groceries',
  'rent',
  'utilities',
  'insurance',
  'healthcare',
  'medical',
  'transportation',
  'gas',
  'public_transit',
  'childcare',
  'education',
  'loan_payments',
])

// ============================================================
// Helper functions
// ============================================================

function isNeedsCategory(pfcPrimary: string | null, pfcDetailed: string | null, flamoraSubcategory: string | null): boolean {
  if (flamoraSubcategory && NEEDS_SUBCATEGORIES.has(flamoraSubcategory)) return true
  if (pfcPrimary && NEEDS_PFC_PRIMARY.has(pfcPrimary)) return true
  if (pfcDetailed) {
    if (pfcDetailed.includes('GROCERIES')) return true
    for (const prefix of NEEDS_PFC_DETAILED_PREFIXES) {
      if (pfcDetailed.startsWith(prefix)) return true
    }
  }
  return false
}

function isWantsCategory(pfcPrimary: string | null, flamoraSubcategory: string | null): boolean {
  if (flamoraSubcategory && WANTS_SUBCATEGORIES.has(flamoraSubcategory)) return true
  if (pfcPrimary && WANTS_PFC_PRIMARY.has(pfcPrimary)) return true
  return false
}

function normalizeCategoryKey(value: string | null | undefined): string | null {
  if (!value) return null
  const trimmed = value.trim()
  return trimmed.length > 0 ? trimmed : null
}

function classifyBudgetBucket(
  pfcPrimary: string | null,
  pfcDetailed: string | null,
  flamoraSubcategory: string | null,
): 'needs' | 'wants' {
  if (isNeedsCategory(pfcPrimary, pfcDetailed, flamoraSubcategory)) return 'needs'
  if (isWantsCategory(pfcPrimary, flamoraSubcategory)) return 'wants'
  return 'wants'
}

function categoryKeyForBucket(
  bucket: 'needs' | 'wants',
  pfcPrimary: string | null,
  pfcDetailed: string | null,
  flamoraSubcategory: string | null,
): string {
  if (bucket === 'needs') {
    return normalizeCategoryKey(pfcDetailed)
      || normalizeCategoryKey(pfcPrimary)
      || 'OTHER_NEEDS'
  }

  return normalizeCategoryKey(flamoraSubcategory)
    || normalizeCategoryKey(pfcDetailed)
    || normalizeCategoryKey(pfcPrimary)
    || 'OTHER_WANTS'
}

function resolveOverrideBucket(
  overrideMap: Map<string, string>,
  txn: {
    merchant_name?: string | null
    name?: string | null
    pfc_detailed?: string | null
    flamora_subcategory?: string | null
    pfc_primary?: string | null
  }
): 'needs' | 'wants' | null {
  const candidates = [
    txn.merchant_name,
    txn.name,
    txn.pfc_detailed,
    txn.flamora_subcategory,
    txn.pfc_primary,
  ]

  for (const candidate of candidates) {
    const key = normalizeCategoryKey(candidate)
    if (!key) continue
    const override = overrideMap.get(key)
    if (override === 'fixed') return 'needs'
    if (override === 'flexible') return 'wants'
  }

  return null
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
    // 4b. Determine effective account scope (depository + credit only)
    // ============================================================
    // Default to active cashflow accounts unless caller provides explicit account_ids.
    // This prevents investment transactions from polluting the spending analysis.
    let effectiveAccountIds: string[] | null =
      body.account_ids && body.account_ids.length > 0 ? body.account_ids : null

    if (!effectiveAccountIds) {
      const { data: cashAccounts } = await supabase
        .from('plaid_accounts')
        .select('id')
        .eq('user_id', user.id)
        .in('type', ['depository', 'credit'])
        .eq('is_active', true)
      if (cashAccounts && cashAccounts.length > 0) {
        effectiveAccountIds = cashAccounts.map((a: any) => a.id)
      }
    }

    // ============================================================
    // 5. Fetch all expense transactions
    // ============================================================
    let rawExpenseTxns: any[] = []
    let expError: any = null

    if (effectiveAccountIds && effectiveAccountIds.length > 0) {
      const expenseQuery = supabase
        .from('transactions')
        .select('amount, date, name, merchant_name, pfc_primary, pfc_detailed, flamora_category, flamora_subcategory')
        .eq('user_id', user.id)
        .eq('pending', false)
        .in('flamora_category', ['needs', 'wants'])
        .gt('amount', 0)
        .gte('date', startDateStr)
        .in('plaid_account_id', effectiveAccountIds)
        .order('date', { ascending: true })

      const expenseResponse = await expenseQuery
      rawExpenseTxns = expenseResponse.data || []
      expError = expenseResponse.error
    }

    if (expError) {
      console.error('Error fetching expense transactions:', expError)
      return new Response(
        JSON.stringify({ success: false, error: { code: 'QUERY_ERROR', message: expError.message } }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Exclude fund-movement noise: transfers and credit card payments.
    // Without this, a credit card payment from checking counts as a "needs" expense
    // while the individual charges on the credit card are also counted — double-counting.
    const EXCLUDE_PFC_PRIMARY = new Set(['TRANSFER_IN', 'TRANSFER_OUT'])
    const expenseTxns = (rawExpenseTxns || []).filter((t: any) =>
      !EXCLUDE_PFC_PRIMARY.has(t.pfc_primary || '') &&
      t.pfc_detailed !== 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'
    )

    // ============================================================
    // 6. Fetch income transactions
    // ============================================================
    let rawIncomeTxns: any[] = []
    let rawIncomeTxnsAlt: any[] = []

    if (effectiveAccountIds && effectiveAccountIds.length > 0) {
      const incomeQuery = supabase
        .from('transactions')
        .select('amount, date, pfc_primary')
        .eq('user_id', user.id)
        .eq('pending', false)
        .lt('amount', 0)  // Plaid: income = negative amount
        .gte('date', startDateStr)
        .in('plaid_account_id', effectiveAccountIds)

      // Also check for pfc_primary = 'INCOME' with positive amounts (some Plaid setups)
      const incomeAltQuery = supabase
        .from('transactions')
        .select('amount, date, pfc_primary')
        .eq('user_id', user.id)
        .eq('pending', false)
        .eq('pfc_primary', 'INCOME')
        .gt('amount', 0)
        .gte('date', startDateStr)
        .in('plaid_account_id', effectiveAccountIds)

      const incomeResponse = await incomeQuery
      rawIncomeTxns = incomeResponse.data || []

      const incomeAltResponse = await incomeAltQuery
      rawIncomeTxnsAlt = incomeAltResponse.data || []
    }

    // Exclude TRANSFER_IN from income: savings→checking moves aren't real income.
    const incomeTxns = (rawIncomeTxns || []).filter((t: any) => t.pfc_primary !== 'TRANSFER_IN')
    const incomeTxnsAlt = (rawIncomeTxnsAlt || []).filter((t: any) => t.pfc_primary !== 'TRANSFER_IN')

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
    // 10. Classify expenses into budget buckets and category groups
    // ============================================================
    interface CategoryAccumulator {
      key: string
      pfcDetailed: string | null
      totalAmount: number
      txnCount: number
      months: Set<string>
      monthlyTotals: Map<string, number>
    }

    const needsByCategory = new Map<string, CategoryAccumulator>()
    const wantsByCategory = new Map<string, CategoryAccumulator>()
    const txnBucketByMonth = new Map<string, { needs: number; wants: number }>()

    function getAccumulator(
      store: Map<string, CategoryAccumulator>,
      key: string,
      pfcDetailed: string | null,
    ) {
      if (!store.has(key)) {
        store.set(key, {
          key,
          pfcDetailed,
          totalAmount: 0,
          txnCount: 0,
          months: new Set(),
          monthlyTotals: new Map(),
        })
      }
      return store.get(key)!
    }

    let totalExpenses = 0

    for (const txn of expenseTxns) {
      const month = getMonthKey(txn.date)
      const bucket = resolveOverrideBucket(overrideMap, txn)
        || classifyBudgetBucket(txn.pfc_primary, txn.pfc_detailed, txn.flamora_subcategory)
      const categoryKey = categoryKeyForBucket(
        bucket,
        txn.pfc_primary,
        txn.pfc_detailed,
        txn.flamora_subcategory
      )
      const store = bucket === 'needs' ? needsByCategory : wantsByCategory
      const accumulator = getAccumulator(store, categoryKey, txn.pfc_detailed)

      accumulator.totalAmount += txn.amount
      accumulator.txnCount += 1
      accumulator.months.add(month)
      accumulator.monthlyTotals.set(month, (accumulator.monthlyTotals.get(month) || 0) + txn.amount)

      const monthBucket = txnBucketByMonth.get(month) || { needs: 0, wants: 0 }
      monthBucket[bucket] += txn.amount
      txnBucketByMonth.set(month, monthBucket)

      totalExpenses += txn.amount
    }

    // ============================================================
    // 11. Build needs / wants output
    // ============================================================
    const fixedExpenses: FixedExpenseItem[] = []
    for (const category of needsByCategory.values()) {
      const monthlyAmounts = Array.from(category.monthlyTotals.values())
      const median = calculateMedian(monthlyAmounts)
      const maxVariance = monthlyAmounts.length > 0
        ? Math.max(...monthlyAmounts.map(a => median > 0 ? Math.abs(a - median) / median : 0))
        : 0

      const avgMonthlyAmount = category.totalAmount / monthsAnalyzed
      fixedExpenses.push({
        name: category.key,
        pfc_detailed: category.pfcDetailed,
        avg_monthly_amount: round2(avgMonthlyAmount),
        months_appeared: category.months.size,
        variance_pct: round2(maxVariance),
        is_always_fixed: true,
      })
    }

    const totalWantsSpending = Array.from(wantsByCategory.values())
      .reduce((sum, category) => sum + category.totalAmount, 0)

    // ============================================================
    // 12. Calculate averages
    // ============================================================
    const avgMonthlyExpenses = totalExpenses / monthsAnalyzed
    const avgMonthlyFixedCalc = fixedExpenses.reduce((sum, f) => sum + f.avg_monthly_amount, 0)
    const avgMonthlyFlexible = totalWantsSpending / monthsAnalyzed
    const avgMonthlySavings = avgMonthlyIncome - avgMonthlyExpenses
    const currentSavingsRate = avgMonthlyIncome > 0
      ? (avgMonthlySavings / avgMonthlyIncome) * 100
      : 0

    // ============================================================
    // 13. Build flexible breakdown
    // ============================================================
    const flexibleBreakdown: FlexibleBreakdownItem[] = Array.from(wantsByCategory.values())
      .map((category) => ({
        subcategory: category.key,
        avg_monthly_amount: round2(category.totalAmount / monthsAnalyzed),
        share_of_flexible: totalWantsSpending > 0
          ? round2(category.totalAmount / totalWantsSpending)
          : 0,
        transaction_count: category.txnCount,
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

    const monthlyBreakdown: MonthlyBreakdownItem[] = Array.from(allExpenseMonths)
      .sort()
      .map(month => {
        const monthBucket = txnBucketByMonth.get(month) || { needs: 0, wants: 0 }
        const fixedTotal = monthBucket.needs
        const flexibleTotal = monthBucket.wants

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
