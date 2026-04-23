// supabase/functions/calculate-spending-stats/index.ts
//
// V3 Budget Module — Step 3 ("Your Reality") source of truth.
// Pure algorithm lives in `_shared/spending-stats-core.ts`; this file is
// auth + DB I/O + response shaping only.
//
// Response shape:
//   - Legacy fields (avg_monthly_income, fixed_expenses, flexible_breakdown,
//     monthly_breakdown) are preserved so the iOS Step 3 view keeps decoding
//     during Phase E migration.
//   - New v3 fields (has_deficit, essential_floor, canonical_breakdown,
//     one_time_transactions, monthly_breakdown_v3) carry the data the new
//     Step 3 / generate-plans contract needs.
//
// B5: the manual-input fallback was removed. If the user has no Plaid
// transactions in the window we return 200 with empty data + has_deficit=false
// rather than fabricating a 40/60 split. Setup Step 1 Skip path is supposed
// to bypass this function entirely (frontend collects 4 manual numbers and
// feeds generate-plans directly).

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import {
  computeSpendingStats,
  type InputTransaction,
  type SpendingStatsResult,
} from '../_shared/spending-stats-core.ts'
import { CANONICAL_PARENT, type CanonicalId } from '../_shared/plaid-to-canonical.ts'

interface RequestBody {
  months?: number
  account_ids?: string[]
}

function round2(value: number): number {
  return Math.round(value * 100) / 100
}

/** Build "yyyy-mm" from a Date in UTC. */
function monthKey(d: Date): string {
  const y = d.getUTCFullYear()
  const m = String(d.getUTCMonth() + 1).padStart(2, '0')
  return `${y}-${m}`
}

/**
 * Adapt the V3 result back to the legacy SpendingStatsResponse shape iOS
 * decodes today (`Models/BudgetSetupModels.swift`). currentSavingsRate is
 * intentionally returned as a percentage (0..100) — that is the legacy
 * contract; generate-plans request also expects percent.
 */
function buildLegacyShape(result: SpendingStatsResult) {
  const fixedExpenses = result.canonicalBreakdown
    .filter(c => c.parent === 'needs' && c.transactionCount > 0)
    .map(c => ({
      name: c.canonicalId,
      pfc_detailed: null,
      avg_monthly_amount: round2(c.avgMonthly),
      months_appeared: result.monthsAnalyzed,
      variance_pct: 0,
      is_always_fixed: true,
    }))
    .sort((a, b) => b.avg_monthly_amount - a.avg_monthly_amount)

  const totalWants = result.avgWants
  const flexibleBreakdown = result.canonicalBreakdown
    .filter(c => c.parent === 'wants' && c.transactionCount > 0)
    .map(c => ({
      subcategory: c.canonicalId,
      avg_monthly_amount: round2(c.avgMonthly),
      share_of_flexible: totalWants > 0 ? round2(c.avgMonthly / totalWants) : 0,
      transaction_count: c.transactionCount,
    }))
    .sort((a, b) => b.avg_monthly_amount - a.avg_monthly_amount)

  const avgMonthlyFixed = result.canonicalBreakdown
    .filter(c => c.parent === 'needs')
    .reduce((s, c) => s + c.avgMonthly, 0)

  const monthly_breakdown = result.monthlyBreakdown.map(row => ({
    month: row.month,
    income: round2(row.income),
    fixed: round2(row.needsSpend),
    flexible: round2(row.wantsSpend + row.uncategorizedSpend),
    savings: round2(row.savings),
  }))

  return { fixedExpenses, flexibleBreakdown, avgMonthlyFixed, monthly_breakdown }
}

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    // ---------- Auth ----------
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, error: { code: 'UNAUTHORIZED', message: 'Missing Authorization header' } }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const supabaseAuth = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    )

    const { data: { user }, error: authError } = await supabaseAuth.auth.getUser()
    if (authError || !user) {
      return new Response(
        JSON.stringify({ success: false, error: { code: 'UNAUTHORIZED', message: 'Invalid token' } }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    // ---------- Request ----------
    let body: RequestBody = {}
    try { body = await req.json() } catch { /* empty body OK */ }

    const months = Math.max(1, body.months || 6)
    // Fetch a wider lookback first, then shrink to the most recent N complete
    // analysis months. This avoids the "5 of 6 complete" problem when the
    // latest 6-calendar-month window contains a sparse month but the user has
    // older complete history we can still use.
    //
    // Example:
    //   Today: 2026-04-23
    //   Broad lookback: up to ~18 months ending 2026-03
    //   Final analysis set: most recent 6 months marked `complete`
    const now = new Date()
    const currentMonthStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1))
    const endDate = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - 1, 1))
    const lookbackMonths = Math.max(months * 3, 18)
    const startDate = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - lookbackMonths, 1))
    const startMonth = monthKey(startDate)
    const endMonth = monthKey(endDate)
    const startDateStr = `${startMonth}-01`
    const currentMonthStartStr = `${monthKey(currentMonthStart)}-01`

    // ---------- Account scope (depository + credit only) ----------
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
        effectiveAccountIds = cashAccounts.map((a: { id: string }) => a.id)
      }
    }

    if (!effectiveAccountIds || effectiveAccountIds.length === 0) {
      return new Response(
        JSON.stringify({
          success: false,
          error: { code: 'NO_ACCOUNTS', message: 'No active depository or credit accounts. Connect one in Step 1 or use the manual entry path.' },
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    // ---------- Fetch transactions in one shot ----------
    // Cover spend (positive amount) AND income (negative amount or INCOME pfc),
    // then let the pure core decide. This is simpler than the 3-query split
    // the old handler used.
    const { data: rawTxns, error: txnError } = await supabase
      .from('transactions')
      .select('amount, date, name, merchant_name, pfc_primary, pfc_detailed, flamora_category, flamora_subcategory')
      .eq('user_id', user.id)
      .eq('pending', false)
      .gte('date', startDateStr)
      .lt('date', currentMonthStartStr)
      .in('plaid_account_id', effectiveAccountIds)
      .order('date', { ascending: true })

    if (txnError) {
      console.error('Error fetching transactions:', txnError)
      return new Response(
        JSON.stringify({ success: false, error: { code: 'QUERY_ERROR', message: txnError.message } }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const inputTxns: InputTransaction[] = (rawTxns || []).map((t: {
      amount: number; date: string; name: string | null; pfc_primary: string | null;
      pfc_detailed: string | null; flamora_category: string | null; flamora_subcategory: string | null
    }) => ({
      amount: t.amount,
      date: t.date,
      name: t.name,
      pfc_primary: t.pfc_primary,
      pfc_detailed: t.pfc_detailed,
      flamora_category: t.flamora_category,
      flamora_subcategory: t.flamora_subcategory,
    }))

    // ---------- Pure compute ----------
    const broadResult = computeSpendingStats(inputTxns, {
      windowStartMonth: startMonth,
      windowEndMonth: endMonth,
    })

    const completeMonthKeys = broadResult.monthlyBreakdown
      .filter((row) => row.status === 'complete')
      .map((row) => row.month)

    const selectedMonthKeys = completeMonthKeys.slice(-months)
    const selectedMonthSet = new Set(selectedMonthKeys)

    let result: SpendingStatsResult = broadResult
    if (selectedMonthKeys.length > 0) {
      const narrowedTransactions = inputTxns.filter((txn) => selectedMonthSet.has(txn.date.substring(0, 7)))
      const narrowed = computeSpendingStats(narrowedTransactions, {
        windowStartMonth: selectedMonthKeys[0],
        windowEndMonth: selectedMonthKeys[selectedMonthKeys.length - 1],
      })

      result = {
        ...narrowed,
        monthlyBreakdown: narrowed.monthlyBreakdown.filter((row) => selectedMonthSet.has(row.month)),
        monthsAnalyzed: selectedMonthKeys.length,
        monthsInWindow: selectedMonthKeys.length,
      }
    }

    // ---------- Shape response (legacy + v3) ----------
    const legacy = buildLegacyShape(result)
    const dataQuality = result.monthsAnalyzed >= 3 ? 'good' : 'limited'
    const totalTxns = result.totalRegularTransactions + result.totalOneTimeTransactions

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          // ----- Legacy fields (kept for iOS Phase E migration) -----
          avg_monthly_income: round2(result.avgMonthlyIncome),
          avg_monthly_expenses: round2(result.avgMonthlyExpense),
          avg_monthly_savings: round2(result.avgMonthlySavings),
          // legacy contract: percent (0..100), clamped to ≥ 0 (B1)
          current_savings_rate: round2(result.currentSavingsRate * 100),
          avg_monthly_fixed: round2(legacy.avgMonthlyFixed),
          avg_monthly_flexible: round2(result.avgWants),
          fixed_expenses: legacy.fixedExpenses,
          flexible_breakdown: legacy.flexibleBreakdown,
          income_source: 'plaid',
          months_analyzed: result.monthsAnalyzed,
          data_quality: dataQuality,
          total_transactions: totalTxns,
          monthly_breakdown: legacy.monthly_breakdown,

          // ----- v3 fields (Step 3 / generate-plans contract) -----
          has_deficit: result.hasDeficit,
          deficit_amount: round2(result.deficitAmount),
          essential_floor: round2(result.essentialFloor),
          avg_wants: round2(result.avgWants),
          uncategorized_share_of_spend: round2(result.uncategorizedShareOfSpend),
          canonical_breakdown: result.canonicalBreakdown.map(c => ({
            canonical_id: c.canonicalId,
            parent: c.parent,
            avg_monthly: round2(c.avgMonthly),
            transaction_count: c.transactionCount,
          })),
          one_time_transactions: result.oneTimeTransactions.map(t => ({
            amount: round2(t.amount),
            date: t.date,
            name: t.name,
            pfc_detailed: t.pfcDetailed,
            canonical_id: t.canonicalId,
          })),
          outlier_threshold: round2(result.outlierThreshold),
          monthly_breakdown_v3: result.monthlyBreakdown.map(row => ({
            month: row.month,
            status: row.status,
            income: round2(row.income),
            needs_spend: round2(row.needsSpend),
            wants_spend: round2(row.wantsSpend),
            uncategorized_spend: round2(row.uncategorizedSpend),
            total_spend: round2(row.totalSpend),
            savings: round2(row.savings),
          })),
          months_in_window: result.monthsInWindow,
          analysis_months: selectedMonthKeys,
          requested_complete_months: months,
          complete_month_count: selectedMonthKeys.length,
        },
        meta: { timestamp: new Date().toISOString(), user_id: user.id, version: 'v3' },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (error) {
    console.error('Error in calculate-spending-stats:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: { code: 'INTERNAL_SERVER_ERROR', message: (error as Error).message || 'An unexpected error occurred' },
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})
