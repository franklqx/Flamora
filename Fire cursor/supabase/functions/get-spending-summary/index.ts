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
    // 3. 获取当月所有 needs + wants 交易
    // ============================================================
    const { data: transactions, error: txError } = await supabase
      .from('transactions')
      .select('amount, flamora_category, flamora_subcategory')
      .eq('user_id', user.id)
      .in('flamora_category', ['needs', 'wants'])
      .eq('pending', false)
      .gte('date', startDate)
      .lte('date', endDate)

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
    const formatSubcategories = (map: Record<string, number>) =>
      Object.entries(map)
        .map(([name, amount]) => ({
          subcategory: name,
          amount: parseFloat(amount.toFixed(2)),
          percentage: totalSpending > 0
            ? parseFloat(((amount / totalSpending) * 100).toFixed(1))
            : 0,
        }))
        .sort((a, b) => b.amount - a.amount)

    // ============================================================
    // 5. 获取预算数据（如果有）
    // ============================================================
    const { data: budget } = await supabase
      .from('budgets')
      .select('needs_budget, wants_budget, savings_budget')
      .eq('user_id', user.id)
      .eq('month', startDate)
      .single()

    // ============================================================
    // 6. 获取当月收入
    // ============================================================
    const { data: incomeTxns } = await supabase
      .from('transactions')
      .select('amount')
      .eq('user_id', user.id)
      .eq('flamora_category', 'income')
      .eq('pending', false)
      .gte('date', startDate)
      .lte('date', endDate)

    const incomeTotal = (incomeTxns || []).reduce(
      (sum: number, tx: any) => sum + Math.abs(tx.amount), 0
    )

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
            subcategories: formatSubcategories(needsBySubcategory),
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
            subcategories: formatSubcategories(wantsBySubcategory),
          },

          savings: {
            budget: budget?.savings_budget || null,
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