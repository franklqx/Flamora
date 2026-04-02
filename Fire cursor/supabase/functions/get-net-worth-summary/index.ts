// supabase/functions/get-net-worth-summary/index.ts

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 🔐 从 Authorization header 获取用户
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, error: { code: 'UNAUTHORIZED', message: 'Missing Authorization header' } }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)

    if (authError || !user) {
      return new Response(
        JSON.stringify({ success: false, error: { code: 'UNAUTHORIZED', message: 'Invalid token' } }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 获取用户档案
    const { data: profile, error: profileError } = await supabase
      .from('user_profiles')
      .select('current_net_worth, has_linked_bank, plaid_net_worth, plaid_net_worth_updated_at')
      .eq('user_id', user.id)
      .single()

    if (profileError || !profile) {
      return new Response(
        JSON.stringify({ success: false, error: { code: 'NO_PROFILE_FOUND', message: 'User profile not found.' } }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ========== 根据是否连接银行，返回不同数据 ==========

    if (profile.has_linked_bank) {
      // ✅ 已连接 Plaid：从真实账户数据计算

      // 获取所有活跃 Plaid 账户（is_active=true 确保只汇总用户在 Link 里勾选的账户）
      const { data: accounts, error: accountsError } = await supabase
        .from('plaid_accounts')
        .select(`
          id,
          account_id,
          name,
          type,
          subtype,
          balance_current,
          mask,
          plaid_items ( institution_name )
        `)
        .eq('user_id', user.id)
        .eq('is_active', true)

      if (accountsError) {
        console.error('Error fetching accounts:', accountsError)
      }

      const accountList = accounts || []

      const bal = (a: { balance_current?: number | null }) => a.balance_current ?? 0

      // 按类型汇总
      const investmentTotal = accountList
        .filter(a => a.type === 'investment')
        .reduce((sum, a) => sum + bal(a), 0)

      const depositoryTotal = accountList
        .filter(a => a.type === 'depository')
        .reduce((sum, a) => sum + bal(a), 0)

      const creditTotal = accountList
        .filter(a => a.type === 'credit')
        .reduce((sum, a) => sum + bal(a), 0)

      const loanTotal = accountList
        .filter(a => a.type === 'loan')
        .reduce((sum, a) => sum + bal(a), 0)

      const totalNetWorth = depositoryTotal + investmentTotal - creditTotal - loanTotal

      // 获取上月净资产（从 net_worth_history）
      const lastMonth = new Date()
      lastMonth.setMonth(lastMonth.getMonth() - 1)
      const lastMonthStr = lastMonth.toISOString().slice(0, 10)

      const { data: previousRecord } = await supabase
        .from('net_worth_history')
        .select('total_net_worth')
        .eq('user_id', user.id)
        .lte('date', lastMonthStr)
        .order('date', { ascending: false })
        .limit(1)
        .single()

      const previousNetWorth = previousRecord?.total_net_worth ?? totalNetWorth
      const growthAmount = totalNetWorth - previousNetWorth
      const growthPercentage = previousNetWorth > 0
        ? parseFloat(((growthAmount / previousNetWorth) * 100).toFixed(2))
        : 0

      // 获取 FIRE 进度
      const { data: fireGoal } = await supabase
        .from('fire_goals')
        .select('fire_number')
        .eq('user_id', user.id)
        .eq('is_active', true)
        .single()

      const fireProgressPercentage = fireGoal?.fire_number
        ? parseFloat(((investmentTotal / fireGoal.fire_number) * 100).toFixed(2))
        : 0

      return new Response(
        JSON.stringify({
          success: true,
          data: {
            total_net_worth: totalNetWorth,
            previous_net_worth: previousNetWorth,
            growth_amount: growthAmount,
            growth_percentage: growthPercentage,
            as_of_date: new Date().toISOString().slice(0, 10),
            breakdown: {
              investment_total: investmentTotal,
              depository_total: depositoryTotal,
              credit_total: creditTotal,
              loan_total: loanTotal,
            },
            fire_progress_percentage: fireProgressPercentage,
            last_synced_at: profile.plaid_net_worth_updated_at ?? null,
            // id 必须为字符串且不可省略：JSON.stringify 会丢弃 undefined，客户端会报 Key 'id' not found
            accounts: accountList.map((a: any) => {
              const rowId = a.id != null && String(a.id) !== ''
                ? String(a.id)
                : (a.account_id != null ? String(a.account_id) : '')
              return {
                id: rowId,
                account_id: a.account_id ?? null,
                name: a.name ?? '',
                type: a.type ?? 'depository',
                subtype: a.subtype ?? null,
                balance: a.balance_current ?? null,
                mask: a.mask ?? null,
                institution: a.plaid_items?.institution_name ?? '',
              }
            }),
            data_source: 'plaid',
          },
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )

    } else {
      // ❌ 未连接 Plaid：用 Onboarding 手动数据
      const totalNetWorth = profile.current_net_worth || 0

      return new Response(
        JSON.stringify({
          success: true,
          data: {
            total_net_worth: totalNetWorth,
            previous_net_worth: null,
            growth_amount: null,
            growth_percentage: null,
            as_of_date: new Date().toISOString().slice(0, 10),
            breakdown: {
              investment_total: null,
              depository_total: null,
              credit_total: null,
              loan_total: null,
            },
            fire_progress_percentage: null,
            last_synced_at: null,
            accounts: [],
            data_source: 'manual',
          },
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

  } catch (error) {
    console.error('Error in get-net-worth-summary:', error)

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