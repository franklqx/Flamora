// supabase/functions/get-spending-summary/index.ts

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    // ============================================================
    // 1. 身份验证
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

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // ============================================================
    // 2. 解析查询参数
    // ============================================================
    const url = new URL(req.url)
    const month = url.searchParams.get('month') // 格式: 2026-02

    // 默认当前月
    const now = new Date()
    const targetMonth = month || `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`
    const startDate = `${targetMonth}-01`

    // 计算月末
    const [year, mon] = targetMonth.split('-').map(Number)
    const lastDay = new Date(year, mon, 0).getDate()
    const endDate = `${targetMonth}-${String(lastDay).padStart(2, '0')}`

    // ============================================================
    // 2b. 仅使用 depository + credit 账户（排除投资账户交易）
    // ============================================================
    const { data: cashAccounts } = await supabase
      .from('plaid_accounts')
      .select('id, name, official_name, mask')
      .eq('user_id', user.id)
      .in('type', ['depository', 'credit'])
      .eq('is_active', true)
    const cashAccountIds: string[] = (cashAccounts || []).map((a: any) => a.id)

    const accountLabelById = new Map<string, string>()
    for (const a of cashAccounts || []) {
      const base = String((a.official_name || a.name || '').trim() || 'Account')
      const mask = String((a.mask || '').trim())
      accountLabelById.set(a.id, mask ? `${base} · ${mask}` : base)
    }

    // ============================================================
    // 3. 获取当月所有 needs + wants 交易
    // ============================================================
    let rawTransactions: any[] = []
    let txError: any = null

    if (cashAccountIds.length > 0) {
      const txQuery = supabase
        .from('transactions')
        .select('amount, flamora_category, flamora_subcategory, pfc_primary, pfc_detailed')
        .eq('user_id', user.id)
        .in('flamora_category', ['needs', 'wants'])
        .eq('pending', false)
        .gte('date', startDate)
        .lte('date', endDate)
        .in('plaid_account_id', cashAccountIds)

      const txResponse = await txQuery
      rawTransactions = txResponse.data || []
      txError = txResponse.error
    }

    // 排除资金搬运类交易（转账、信用卡还款）以防双重计算
    const EXCLUDE_PFC_PRIMARY = new Set(['TRANSFER_IN', 'TRANSFER_OUT'])
    const transactions = (rawTransactions || []).filter((t: any) =>
      !EXCLUDE_PFC_PRIMARY.has(t.pfc_primary || '') &&
      t.pfc_detailed !== 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT'
    )

    if (txError) {
      console.error('Error fetching transactions:', txError)
      return new Response(
        JSON.stringify({ success: false, error: { code: 'QUERY_ERROR', message: txError.message } }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ============================================================
    // 4. 计算汇总
    // ============================================================
    let needsTotal = 0
    let wantsTotal = 0
    const needsBySubcategory: Record<string, number> = {}
    const wantsBySubcategory: Record<string, number> = {}

    for (const tx of transactions || []) {
      // Plaid: 正数 = 支出
      if (tx.amount <= 0) continue

      if (tx.flamora_category === 'needs') {
        needsTotal += tx.amount
        const sub = tx.flamora_subcategory || 'uncategorized'
        needsBySubcategory[sub] = (needsBySubcategory[sub] || 0) + tx.amount
      } else if (tx.flamora_category === 'wants') {
        wantsTotal += tx.amount
        const sub = tx.flamora_subcategory || 'uncategorized'
        wantsBySubcategory[sub] = (wantsBySubcategory[sub] || 0) + tx.amount
      }
    }

    const totalSpending = needsTotal + wantsTotal

    // 转换子分类为排序后的数组
    const formatSubcategories = (map: Record<string, number>, bucketTotal: number) =>
      Object.entries(map)
        .map(([name, amount]) => ({
          subcategory: name,
          amount: parseFloat(amount.toFixed(2)),
          percentage: bucketTotal > 0
            ? parseFloat(((amount / bucketTotal) * 100).toFixed(1))
            : 0,
        }))
        .sort((a, b) => b.amount - a.amount)

    // ============================================================
    // 5. 获取预算数据（如果有）
    // ============================================================
    const { data: budget } = await supabase
      .from('budgets')
      .select('needs_budget, wants_budget, savings_budget, savings_actual')
      .eq('user_id', user.id)
      .eq('month', startDate)
      .single()

    // ============================================================
    // 6. 获取当月收入（含 subcategory 以区分 active / passive）
    // ============================================================
    let incomeTxns: any[] = []
    if (cashAccountIds.length > 0) {
      const { data } = await supabase
        .from('transactions')
        .select('amount, flamora_subcategory, merchant_name, name, pfc_primary, plaid_account_id, date')
        .eq('user_id', user.id)
        .eq('flamora_category', 'income')
        .eq('pending', false)
        .gte('date', startDate)
        .lte('date', endDate)
        .in('plaid_account_id', cashAccountIds)

      incomeTxns = (data || []).filter((tx: any) => tx.pfc_primary !== 'TRANSFER_IN')
    }

    // 被动收入子类别（不区分大小写匹配前缀/全名）
    const PASSIVE_SUBS = new Set([
      'interest', 'dividend', 'dividends', 'rental', 'rental_income',
      'investment_income', 'royalty', 'royalties', 'passive'
    ])

    type IncomeTxSlice = { abs: number; plaid_account_id: string | null; date: string }
    type IncomeBucket = { amount: number; txs: IncomeTxSlice[] }

    let activeIncome = 0
    let passiveIncome = 0
    const activeBuckets: Record<string, IncomeBucket> = {}
    const passiveBuckets: Record<string, IncomeBucket> = {}

    const pushBucket = (map: Record<string, IncomeBucket>, key: string, slice: IncomeTxSlice) => {
      if (!map[key]) map[key] = { amount: 0, txs: [] }
      map[key].amount += slice.abs
      map[key].txs.push(slice)
    }

    for (const tx of incomeTxns || []) {
      const abs = Math.abs(tx.amount)
      const sub = (tx.flamora_subcategory || '').toLowerCase()
      const displayName = tx.merchant_name || tx.name || sub || 'Income'
      const isPassive = PASSIVE_SUBS.has(sub) || sub.startsWith('interest') || sub.startsWith('dividend')
      const dateStr = typeof tx.date === 'string' ? tx.date : String(tx.date || '')
      const slice: IncomeTxSlice = {
        abs,
        plaid_account_id: tx.plaid_account_id ?? null,
        date: dateStr,
      }

      if (isPassive) {
        passiveIncome += abs
        pushBucket(passiveBuckets, displayName, slice)
      } else {
        activeIncome += abs
        pushBucket(activeBuckets, displayName, slice)
      }
    }

    const incomeTotal = activeIncome + passiveIncome

    const formatIncomeSources = (
      buckets: Record<string, IncomeBucket>,
      total: number,
    ) => {
      return Object.entries(buckets)
        .map(([name, b]) => {
          let account_name: string | null = null
          let credit_date: string | null = null
          if (b.txs.length > 0) {
            let maxTx = b.txs[0]
            for (const t of b.txs) {
              if (t.abs > maxTx.abs) maxTx = t
            }
            if (maxTx.plaid_account_id) {
              account_name = accountLabelById.get(maxTx.plaid_account_id) ?? null
            }
            let latest = b.txs[0].date
            for (const t of b.txs) {
              if (t.date > latest) latest = t.date
            }
            credit_date = latest || null
          }
          return {
            name,
            amount: parseFloat(b.amount.toFixed(2)),
            percentage: total > 0 ? parseFloat(((b.amount / total) * 100).toFixed(1)) : 0,
            account_name,
            credit_date,
          }
        })
        .sort((a, b) => b.amount - a.amount)
    }

    // ============================================================
    // 7. 返回结果
    // ============================================================
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          month: targetMonth,
          total_spending: parseFloat(totalSpending.toFixed(2)),
          total_income: parseFloat(incomeTotal.toFixed(2)),
          active_income: parseFloat(activeIncome.toFixed(2)),
          passive_income: parseFloat(passiveIncome.toFixed(2)),
          income_active_sources: formatIncomeSources(activeBuckets, activeIncome),
          income_passive_sources: formatIncomeSources(passiveBuckets, passiveIncome),

          needs: {
            total: parseFloat(needsTotal.toFixed(2)),
            percentage: totalSpending > 0
              ? parseFloat(((needsTotal / totalSpending) * 100).toFixed(1))
              : 0,
            budget: budget?.needs_budget || null,
            remaining: budget?.needs_budget
              ? parseFloat((budget.needs_budget - needsTotal).toFixed(2))
              : null,
            over_budget: budget?.needs_budget ? needsTotal > budget.needs_budget : false,
            subcategories: formatSubcategories(needsBySubcategory, needsTotal),
          },

          wants: {
            total: parseFloat(wantsTotal.toFixed(2)),
            percentage: totalSpending > 0
              ? parseFloat(((wantsTotal / totalSpending) * 100).toFixed(1))
              : 0,
            budget: budget?.wants_budget || null,
            remaining: budget?.wants_budget
              ? parseFloat((budget.wants_budget - wantsTotal).toFixed(2))
              : null,
            over_budget: budget?.wants_budget ? wantsTotal > budget.wants_budget : false,
            subcategories: formatSubcategories(wantsBySubcategory, wantsTotal),
          },

          savings: {
            budget: budget?.savings_budget || null,
            actual: budget?.savings_actual || null,
            estimated: parseFloat(Math.max(0, incomeTotal - totalSpending).toFixed(2)),
          },
        },
        meta: {
          timestamp: new Date().toISOString(),
          user_id: user.id,
        },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in get-spending-summary:', error)

    return new Response(
      JSON.stringify({ success: false, error: { code: 'INTERNAL_SERVER_ERROR', message: error.message || 'An unexpected error occurred' } }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
