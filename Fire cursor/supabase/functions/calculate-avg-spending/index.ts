// supabase/functions/calculate-avg-spending/index.ts
//
// UPDATED: Added fallback to Onboarding data when no Plaid transactions available
// Returns { fallback: true } with estimated values instead of 404 error

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

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

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)
    if (authError || !user) {
      return new Response(
        JSON.stringify({ success: false, error: { code: 'UNAUTHORIZED', message: 'Invalid or expired token' } }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ============================================================
    // 2. Parse params
    // ============================================================
    let months = 6
    try {
      const body = await req.json()
      months = body.months || 6
    } catch {
      // No body is fine, use default
    }

    const startDate = new Date()
    startDate.setMonth(startDate.getMonth() - months)
    const startDateStr = startDate.toISOString().split('T')[0]

    // ============================================================
    // 3. Get user profile (needed for fallback + income comparison)
    // ============================================================
    const { data: profile } = await supabase
      .from('user_profiles')
      .select('monthly_income, current_monthly_expenses')
      .eq('user_id', user.id)
      .single()

    const manualIncome = profile?.monthly_income || 0
    const manualExpenses = profile?.current_monthly_expenses || 0

    // ============================================================
    // 4. Fetch transactions (needs + wants)
    // ============================================================
    const { data: transactions, error: txError } = await supabase
      .from('transactions')
      .select('amount, date, flamora_category')
      .eq('user_id', user.id)
      .in('flamora_category', ['needs', 'wants'])
      .eq('pending', false)
      .gte('date', startDateStr)
      .order('date', { ascending: true })

    if (txError) {
      console.error('Error fetching transactions:', txError)
      return new Response(
        JSON.stringify({ success: false, error: { code: 'QUERY_ERROR', message: txError.message } }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ============================================================
    // 5. FALLBACK: No transaction data → use Onboarding estimates
    // ============================================================
    if (!transactions || transactions.length === 0) {
      const estimatedNeeds = manualExpenses * 0.60
      const estimatedWants = manualExpenses * 0.40

      return new Response(
        JSON.stringify({
          success: true,
          data: {
            avg_monthly_spending: parseFloat(manualExpenses.toFixed(2)),
            avg_monthly_needs: parseFloat(estimatedNeeds.toFixed(2)),
            avg_monthly_wants: parseFloat(estimatedWants.toFixed(2)),
            avg_monthly_income_detected: 0,
            months_analyzed: 0,
            outliers_removed: 0,
            outlier_threshold: null,
            income_discrepancy: false,
            manual_income: manualIncome,
            monthly_breakdown: [],
            fallback: true,
          },
          meta: { timestamp: new Date().toISOString(), user_id: user.id },
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ============================================================
    // 6. IQR outlier detection
    // ============================================================
    const spendingAmounts = transactions
      .filter((tx: any) => tx.amount > 0)
      .map((tx: any) => tx.amount)
      .sort((a: number, b: number) => a - b)

    let upperBound = Infinity
    let outliersRemoved = 0

    if (spendingAmounts.length >= 4) {
      const q1Index = Math.floor(spendingAmounts.length * 0.25)
      const q3Index = Math.floor(spendingAmounts.length * 0.75)
      const q1 = spendingAmounts[q1Index]
      const q3 = spendingAmounts[q3Index]
      const iqr = q3 - q1
      upperBound = q3 + 1.5 * iqr
    }

    // ============================================================
    // 7. Monthly aggregation (excluding outliers)
    // ============================================================
    const monthlyTotals: Record<string, { needs: number; wants: number }> = {}

    for (const tx of transactions) {
      if (tx.amount <= 0) continue
      if (tx.amount > upperBound) {
        outliersRemoved++
        continue
      }

      const monthKey = tx.date.substring(0, 7)
      if (!monthlyTotals[monthKey]) {
        monthlyTotals[monthKey] = { needs: 0, wants: 0 }
      }

      if (tx.flamora_category === 'needs') {
        monthlyTotals[monthKey].needs += tx.amount
      } else {
        monthlyTotals[monthKey].wants += tx.amount
      }
    }

    // ============================================================
    // 8. Calculate averages
    // ============================================================
    const monthKeys = Object.keys(monthlyTotals)
    const monthCount = monthKeys.length || 1

    const totalNeeds = monthKeys.reduce((sum, key) => sum + monthlyTotals[key].needs, 0)
    const totalWants = monthKeys.reduce((sum, key) => sum + monthlyTotals[key].wants, 0)

    const avgMonthlyNeeds = totalNeeds / monthCount
    const avgMonthlyWants = totalWants / monthCount
    const avgMonthlySpending = avgMonthlyNeeds + avgMonthlyWants

    const monthlyBreakdown = monthKeys.sort().map(key => ({
      month: key,
      needs: parseFloat(monthlyTotals[key].needs.toFixed(2)),
      wants: parseFloat(monthlyTotals[key].wants.toFixed(2)),
      total: parseFloat((monthlyTotals[key].needs + monthlyTotals[key].wants).toFixed(2)),
    }))

    // ============================================================
    // 9. Detect Plaid income
    // ============================================================
    const { data: incomeTxns } = await supabase
      .from('transactions')
      .select('amount')
      .eq('user_id', user.id)
      .eq('flamora_category', 'income')
      .eq('pending', false)
      .gte('date', startDateStr)

    const totalIncome = (incomeTxns || []).reduce(
      (sum: number, tx: any) => sum + Math.abs(tx.amount), 0
    )
    const avgMonthlyIncomeDetected = totalIncome / monthCount

    // ============================================================
    // 10. Income discrepancy check
    // ============================================================
    const incomeDiscrepancy = manualIncome > 0 &&
      Math.abs(avgMonthlyIncomeDetected - manualIncome) / manualIncome > 0.20

    // ============================================================
    // 11. Return
    // ============================================================
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          avg_monthly_spending: parseFloat(avgMonthlySpending.toFixed(2)),
          avg_monthly_needs: parseFloat(avgMonthlyNeeds.toFixed(2)),
          avg_monthly_wants: parseFloat(avgMonthlyWants.toFixed(2)),
          avg_monthly_income_detected: parseFloat(avgMonthlyIncomeDetected.toFixed(2)),
          months_analyzed: monthCount,
          outliers_removed: outliersRemoved,
          outlier_threshold: upperBound === Infinity ? null : parseFloat(upperBound.toFixed(2)),
          income_discrepancy: incomeDiscrepancy,
          manual_income: manualIncome,
          monthly_breakdown: monthlyBreakdown,
          fallback: false,
        },
        meta: { timestamp: new Date().toISOString(), user_id: user.id },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in calculate-avg-spending:', error)
    return new Response(
      JSON.stringify({ success: false, error: { code: 'INTERNAL_SERVER_ERROR', message: error.message || 'An unexpected error occurred' } }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
