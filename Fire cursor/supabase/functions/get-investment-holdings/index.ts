// supabase/functions/get-investment-holdings/index.ts

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
    // 2. 先查活跃 investment 账户（作为 holdings 查询的过滤基准）
    //    只有 is_active=true AND type='investment' 的账户才算入本次统计
    // ============================================================
    const { data: investmentAccounts } = await supabase
      .from('plaid_accounts')
      .select(`
        id,
        name,
        official_name,
        mask,
        subtype,
        balance_current,
        plaid_items ( institution_name )
      `)
      .eq('user_id', user.id)
      .eq('type', 'investment')
      .eq('is_active', true)

    const activeInvestmentAccounts = investmentAccounts || []
    const activeAccountIds = activeInvestmentAccounts.map((a: any) => a.id)

    // 没有活跃 investment 账户 → 直接返回空结果
    if (activeAccountIds.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          data: {
            summary: {
              total_value: 0,
              total_account_value: 0,
              total_holdings_value: 0,
              uninvested_cash_value: 0,
              total_cost_basis: 0,
              total_gain_loss: null,
              total_gain_loss_pct: null,
              holdings_count: 0,
            },
            type_breakdown: [],
            holdings: [],
            accounts: [],
          },
          meta: { timestamp: new Date().toISOString(), user_id: user.id },
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ============================================================
    // 3. 获取投资持仓 + 证券信息
    //    只查 activeAccountIds 范围内的 holdings，与账户口径一致
    // ============================================================
    const { data: holdings, error: holdingsError } = await supabase
      .from('investment_holdings')
      .select(`
        id,
        plaid_account_id,
        security_id,
        quantity,
        cost_basis,
        institution_price,
        institution_value,
        institution_price_as_of,
        iso_currency_code,
        last_updated,
        plaid_accounts!inner ( name, mask, subtype, plaid_items ( institution_name ) )
      `)
      .eq('user_id', user.id)
      .in('plaid_account_id', activeAccountIds)

    if (holdingsError) {
      console.error('Error fetching holdings:', holdingsError)
      return new Response(
        JSON.stringify({ success: false, error: { code: 'QUERY_ERROR', message: holdingsError.message } }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 获取对应的 securities 信息
    const securityIds = [...new Set((holdings || []).map((h: any) => h.security_id))]

    let securitiesMap = new Map()
    if (securityIds.length > 0) {
      const { data: securities } = await supabase
        .from('securities')
        .select('*')
        .in('security_id', securityIds)

      securitiesMap = new Map(
        (securities || []).map((s: any) => [s.security_id, s])
      )
    }

    // ============================================================
    // 4. 组装持仓数据（只来自 active investment accounts）
    // ============================================================
    const enrichedHoldings = (holdings || []).map((h: any) => {
      const security = securitiesMap.get(h.security_id) || {}
      const gainLoss = h.cost_basis && h.institution_value
        ? h.institution_value - h.cost_basis
        : null
      const gainLossPct = h.cost_basis && h.cost_basis > 0 && gainLoss !== null
        ? parseFloat(((gainLoss / h.cost_basis) * 100).toFixed(2))
        : null

      return {
        id: h.id,
        plaid_account_id: h.plaid_account_id,
        // 证券信息
        name: security.name || 'Unknown',
        ticker: security.ticker_symbol || null,
        type: security.type || null,
        is_cash_equivalent: security.is_cash_equivalent || false,
        // 持仓数据
        quantity: h.quantity,
        price: h.institution_price,
        value: h.institution_value,
        cost_basis: h.cost_basis,
        gain_loss: gainLoss ? parseFloat(gainLoss.toFixed(2)) : null,
        gain_loss_pct: gainLossPct,
        price_as_of: h.institution_price_as_of,
        // 账户归属信息（满足 Step 3 要求 7/8）
        account_name: h.plaid_accounts?.name ?? null,
        account_mask: h.plaid_accounts?.mask ?? null,
        account_subtype: h.plaid_accounts?.subtype ?? null,
        institution_name: h.plaid_accounts?.plaid_items?.institution_name ?? null,
      }
    })

    // 按价值排序（最大的在前）
    enrichedHoldings.sort((a: any, b: any) => (b.value || 0) - (a.value || 0))

    // ============================================================
    // 5. 计算汇总（基于 active investment holdings）
    // ============================================================
    const totalHoldingsValue = enrichedHoldings.reduce((sum: number, h: any) => sum + (h.value || 0), 0)
    const totalCostBasis = enrichedHoldings.reduce((sum: number, h: any) => sum + (h.cost_basis || 0), 0)
    const totalGainLoss = totalCostBasis > 0 ? totalHoldingsValue - totalCostBasis : null
    const totalGainLossPct = totalCostBasis > 0
      ? parseFloat(((totalGainLoss! / totalCostBasis) * 100).toFixed(2))
      : null

    // 按证券类型分组汇总（用于 AssetAllocation 饼图）
    // type_breakdown 只来自 active investment holdings
    const byType: Record<string, number> = {}
    for (const h of enrichedHoldings) {
      const type = h.type || 'other'
      byType[type] = (byType[type] || 0) + (h.value || 0)
    }

    const typeBreakdown = Object.entries(byType)
      .map(([type, value]) => ({
        type,
        value: parseFloat(value.toFixed(2)),
        percentage: totalHoldingsValue > 0
          ? parseFloat(((value / totalHoldingsValue) * 100).toFixed(1))
          : 0,
      }))
      .sort((a, b) => b.value - a.value)

    // total_account_value = active investment accounts 的 balance_current 总和
    const totalAccountValue = activeInvestmentAccounts
      .reduce((sum: number, a: any) => sum + (a.balance_current || 0), 0)

    const uninvestedCashValue = Math.max(0, totalAccountValue - totalHoldingsValue)

    // 最近两次投资历史快照的真实变化，用于详情页「今日变化」。
    const { data: historyRows } = await supabase
      .from('net_worth_history')
      .select('date, investment_total, total_net_worth')
      .eq('user_id', user.id)
      .order('date', { ascending: false })
      .limit(2)

    let todayChange: number | null = null
    let todayChangePct: number | null = null
    if ((historyRows || []).length >= 2) {
      const latest = historyRows![0]
      const previous = historyRows![1]
      const latestValue = latest.investment_total ?? latest.total_net_worth ?? 0
      const previousValue = previous.investment_total ?? previous.total_net_worth ?? 0
      todayChange = parseFloat((latestValue - previousValue).toFixed(2))
      todayChangePct = previousValue > 0
        ? parseFloat((((latestValue - previousValue) / previousValue) * 100).toFixed(2))
        : null
    }

    // 每个 investment account 的持仓市值
    const holdingsValueByAccountId: Record<string, number> = {}
    for (const h of enrichedHoldings) {
      const aid = h.plaid_account_id
      if (aid) holdingsValueByAccountId[aid] = (holdingsValueByAccountId[aid] || 0) + (h.value || 0)
    }

    const accountsBreakdown = activeInvestmentAccounts.map((a: any) => ({
      id: a.id,
      name: a.name || a.official_name || '',
      mask: a.mask ?? null,
      subtype: a.subtype ?? null,
      institution_name: a.plaid_items?.institution_name ?? null,
      balance_current: parseFloat((a.balance_current || 0).toFixed(2)),
      holdings_value: parseFloat((holdingsValueByAccountId[a.id] || 0).toFixed(2)),
      uninvested_cash_value: parseFloat(Math.max(0, (a.balance_current || 0) - (holdingsValueByAccountId[a.id] || 0)).toFixed(2)),
    }))

    // ============================================================
    // 6. 返回结果
    // ============================================================
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          summary: {
            total_value: parseFloat(totalHoldingsValue.toFixed(2)),
            total_account_value: parseFloat(totalAccountValue.toFixed(2)),
            total_holdings_value: parseFloat(totalHoldingsValue.toFixed(2)),
            uninvested_cash_value: parseFloat(uninvestedCashValue.toFixed(2)),
            total_cost_basis: parseFloat(totalCostBasis.toFixed(2)),
            total_gain_loss: totalGainLoss !== null ? parseFloat(totalGainLoss.toFixed(2)) : null,
            total_gain_loss_pct: totalGainLossPct,
            today_change: todayChange,
            today_change_pct: todayChangePct,
            holdings_count: enrichedHoldings.length,
          },
          type_breakdown: typeBreakdown,
          holdings: enrichedHoldings,
          accounts: accountsBreakdown,
        },
        meta: {
          timestamp: new Date().toISOString(),
          user_id: user.id,
        },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in get-investment-holdings:', error)

    return new Response(
      JSON.stringify({ success: false, error: { code: 'INTERNAL_SERVER_ERROR', message: error.message || 'An unexpected error occurred' } }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
