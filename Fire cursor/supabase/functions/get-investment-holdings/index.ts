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
    // 2. 获取投资持仓 + 证券信息
    // ============================================================
    const { data: holdings, error: holdingsError } = await supabase
      .from('investment_holdings')
      .select(`
        id,
        plaid_account_id,
        quantity,
        cost_basis,
        institution_price,
        institution_value,
        institution_price_as_of,
        iso_currency_code,
        last_updated,
        plaid_accounts!inner(name, official_name, mask, type, subtype, balance_current)
      `)
      .eq('user_id', user.id)

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
    // 3. 组装持仓数据
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
        // 账户信息
        account_name: h.plaid_accounts?.name,
        account_mask: h.plaid_accounts?.mask,
      }
    })

    // 按价值排序（最大的在前）
    enrichedHoldings.sort((a: any, b: any) => (b.value || 0) - (a.value || 0))

    // ============================================================
    // 4. 计算汇总
    // ============================================================
    const totalValue = enrichedHoldings.reduce((sum: number, h: any) => sum + (h.value || 0), 0)
    const totalCostBasis = enrichedHoldings.reduce((sum: number, h: any) => sum + (h.cost_basis || 0), 0)
    const totalGainLoss = totalCostBasis > 0 ? totalValue - totalCostBasis : null
    const totalGainLossPct = totalCostBasis > 0
      ? parseFloat(((totalGainLoss! / totalCostBasis) * 100).toFixed(2))
      : null

    // 按类型分组汇总
    const byType: Record<string, number> = {}
    for (const h of enrichedHoldings) {
      const type = h.type || 'other'
      byType[type] = (byType[type] || 0) + (h.value || 0)
    }

    const typeBreakdown = Object.entries(byType)
      .map(([type, value]) => ({
        type,
        value: parseFloat(value.toFixed(2)),
        percentage: totalValue > 0
          ? parseFloat(((value / totalValue) * 100).toFixed(1))
          : 0,
      }))
      .sort((a, b) => b.value - a.value)

    // ============================================================
    // 5. 返回结果
    // ============================================================
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          summary: {
            total_value: parseFloat(totalValue.toFixed(2)),
            total_cost_basis: parseFloat(totalCostBasis.toFixed(2)),
            total_gain_loss: totalGainLoss ? parseFloat(totalGainLoss.toFixed(2)) : null,
            total_gain_loss_pct: totalGainLossPct,
            holdings_count: enrichedHoldings.length,
          },
          type_breakdown: typeBreakdown,
          holdings: enrichedHoldings,
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