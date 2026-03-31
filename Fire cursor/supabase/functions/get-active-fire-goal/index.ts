// supabase/functions/get-active-fire-goal/index.ts

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

    // 1. 获取用户的活跃 FIRE 目标
    const { data: fireGoal, error: goalError } = await supabase
      .from('fire_goals')
      .select('*')
      .eq('user_id', user.id)
      .eq('is_active', true)
      .single()

    if (goalError || !fireGoal) {
      return new Response(
        JSON.stringify({
          success: false,
          error: { code: 'NO_ACTIVE_GOAL', message: 'No active FIRE goal found. Please create one first.' },
        }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 2. 获取用户档案（判断是否连接了银行）
    const { data: profile } = await supabase
      .from('user_profiles')
      .select('current_net_worth, has_linked_bank, plaid_net_worth')
      .eq('user_id', user.id)
      .single()

    // 3. 根据是否连接银行，选择净资产来源
    let currentNetWorth: number
    let dataSource: string

    if (profile?.has_linked_bank && profile?.plaid_net_worth != null) {
      // ✅ 已连接 Plaid：用投资总额作为 FIRE 进度
      currentNetWorth = profile.plaid_net_worth
      dataSource = 'plaid'
    } else {
      // ❌ 未连接：用 Onboarding 手动数据
      currentNetWorth = profile?.current_net_worth || 0
      dataSource = 'manual'
    }

    // 4. 计算衍生数据
    const gapToFire = Math.max(fireGoal.fire_number - currentNetWorth, 0)
    const progressPercentage = fireGoal.fire_number > 0
      ? parseFloat(((currentNetWorth / fireGoal.fire_number) * 100).toFixed(2))
      : 0
    const yearsRemaining = fireGoal.target_retirement_age - fireGoal.current_age

    // on_track 逻辑：当前净资产是否达到线性目标的 90%
    const expectedNetWorth = yearsRemaining > 0
      ? (fireGoal.fire_number / yearsRemaining) * (new Date().getFullYear() - (new Date().getFullYear() - fireGoal.current_age))
      : fireGoal.fire_number
    const onTrack = currentNetWorth >= expectedNetWorth * 0.9

    // 5. 返回结果
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          goal_id: fireGoal.id,
          fire_number: fireGoal.fire_number,
          current_net_worth: currentNetWorth,
          gap_to_fire: gapToFire,
          required_savings_rate: fireGoal.required_savings_rate,
          target_retirement_age: fireGoal.target_retirement_age,
          current_age: fireGoal.current_age,
          years_remaining: yearsRemaining,
          progress_percentage: progressPercentage,
          on_track: onTrack,
          data_source: dataSource,
          created_at: fireGoal.created_at,
        },
        meta: {
          timestamp: new Date().toISOString(),
          user_id: user.id,
        },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in get-active-fire-goal:', error)

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