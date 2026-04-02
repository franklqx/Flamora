// supabase/functions/get-monthly-budget/index.ts

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    // 🔐 Auth: use anon key client to verify JWT (same pattern as create-link-token)
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

    // 解析查询参数（可选的 month）
    const url = new URL(req.url)
    const monthParam = url.searchParams.get('month')
    const targetMonth = monthParam || new Date().toISOString().slice(0, 7)
    const monthStart = `${targetMonth}-01`

    // 获取预算数据
    const { data: budget, error: budgetError } = await supabase
      .from('budgets')
      .select('*')
      .eq('user_id', user.id)
      .eq('month', monthStart)
      .single()

    if (budgetError || !budget) {
      return new Response(
        JSON.stringify({
          success: false,
          error: { code: 'NO_BUDGET_FOUND', message: `No budget found for ${targetMonth}` },
        }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 检查是否连接了银行
    const { data: profile } = await supabase
      .from('user_profiles')
      .select('has_linked_bank')
      .eq('user_id', user.id)
      .single()

    let needsSpent = budget.needs_spent || 0
    let wantsSpent = budget.wants_spent || 0

    if (profile?.has_linked_bank) {
      // ✅ 已连接 Plaid：从 transactions 表实时计算
      const monthEnd = new Date(monthStart)
      monthEnd.setMonth(monthEnd.getMonth() + 1)
      const monthEndStr = monthEnd.toISOString().slice(0, 10)

      const { data: needsData } = await supabase
        .from('transactions')
        .select('amount')
        .eq('user_id', user.id)
        .eq('flamora_category', 'needs')
        .gte('date', monthStart)
        .lt('date', monthEndStr)

      const { data: wantsData } = await supabase
        .from('transactions')
        .select('amount')
        .eq('user_id', user.id)
        .eq('flamora_category', 'wants')
        .gte('date', monthStart)
        .lt('date', monthEndStr)

      needsSpent = (needsData || []).filter(t => t.amount > 0).reduce((sum, t) => sum + t.amount, 0)
      wantsSpent = (wantsData || []).filter(t => t.amount > 0).reduce((sum, t) => sum + t.amount, 0)
    }

    // 计算进度百分比
    const needsPercentage = budget.needs_budget > 0
      ? parseFloat(((needsSpent / budget.needs_budget) * 100).toFixed(2))
      : 0
    const wantsPercentage = budget.wants_budget > 0
      ? parseFloat(((wantsSpent / budget.wants_budget) * 100).toFixed(2))
      : 0
    const onTrack = budget.savings_actual >= budget.savings_budget

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          budget_id: budget.id,
          month: budget.month,
          needs_budget: budget.needs_budget,
          wants_budget: budget.wants_budget,
          savings_budget: budget.savings_budget,
          needs_spent: needsSpent,
          wants_spent: wantsSpent,
          savings_actual: budget.savings_actual,
          needs_ratio: budget.needs_ratio,
          wants_ratio: budget.wants_ratio,
          savings_ratio: budget.savings_ratio,
          selected_plan: budget.selected_plan || null,
          is_custom: budget.is_custom,
          progress: {
            needs_percentage: needsPercentage,
            wants_percentage: wantsPercentage,
            on_track: onTrack,
          },
          data_source: profile?.has_linked_bank ? 'plaid' : 'manual',
        },
        meta: {
          timestamp: new Date().toISOString(),
          user_id: user.id,
        },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in get-monthly-budget:', error)

    return new Response(
      JSON.stringify({
        success: false,
        error: {
          code: 'INTERNAL_SERVER_ERROR',
          message: error.message || 'An unexpected error occurred',
        },
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})