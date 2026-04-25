// supabase/functions/get-user-profile/index.ts
// 统一 JWT auth（与 get-active-fire-goal 等函数一致）

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

    // 🔐 从 Authorization header 获取用户（与其他函数统一）
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({
          success: false,
          error: { code: 'UNAUTHORIZED', message: 'Missing Authorization header' },
        }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)

    if (authError || !user) {
      return new Response(
        JSON.stringify({
          success: false,
          error: { code: 'UNAUTHORIZED', message: 'Invalid or expired token' },
        }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log('✅ Verified user:', user.id, user.email)

    // 获取用户档案
    const { data: profile, error: profileError } = await supabase
      .from('user_profiles')
      .select('*')
      .eq('user_id', user.id)
      .single()

    if (profileError || !profile) {
      console.error('No user profile found:', profileError)
      return new Response(
        JSON.stringify({
          success: false,
          error: {
            code: 'NO_PROFILE_FOUND',
            message: 'User profile not found. Please complete onboarding first.',
          },
        }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 返回成功结果
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          profile_id: profile.id,
          user_id: profile.user_id,
          username: profile.username,
          monthly_income: profile.monthly_income,
          current_net_worth: profile.current_net_worth,
          current_monthly_expenses: profile.current_monthly_expenses,
          currency_code: profile.currency_code,
          timezone: profile.timezone,
          onboarding_completed: profile.onboarding_completed,
          onboarding_step: profile.onboarding_step,
          age: profile.age,
          // Plaid 相关字段
          has_linked_bank: profile.has_linked_bank ?? false,
          plaid_institution_name: profile.plaid_institution_name ?? null,
          plaid_net_worth: profile.plaid_net_worth ?? null,
          starting_portfolio_balance: profile.starting_portfolio_balance ?? null,
          starting_portfolio_source: profile.starting_portfolio_source ?? null,
          starting_portfolio_updated_at: profile.starting_portfolio_updated_at ?? null,
          created_at: profile.created_at,
          updated_at: profile.updated_at,
        },
        meta: {
          timestamp: new Date().toISOString(),
          user_id: user.id,
        },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error in get-user-profile:', error)

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
