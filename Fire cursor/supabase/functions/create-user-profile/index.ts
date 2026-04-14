// supabase/functions/create-user-profile/index.ts

import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { ASSUMPTIONS } from '../_shared/fire-assumptions.ts'

interface OnboardingData {
  user_id: string
  username: string
  motivations: string[]
  age: number
  currency_code: string
  rough_monthly_income: number
  rough_monthly_expenses: number
  rough_net_worth: number
  desired_lifestyle: 'simpler' | 'current' | 'dream'
}

Deno.serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const body: OnboardingData = await req.json()

    // 从 body 获取 user_id
    const userId = body.user_id
    if (!userId) {
      return new Response(
        JSON.stringify({
          success: false,
          error: { code: 'MISSING_USER_ID', message: 'user_id is required in request body' },
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 验证用户存在
    const { data: authUser, error: authError } = await supabase.auth.admin.getUserById(userId)
    if (authError || !authUser?.user) {
      return new Response(
        JSON.stringify({
          success: false,
          error: { code: 'INVALID_USER', message: 'User not found' },
        }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log('✅ Verified user:', userId, authUser.user.email)

    // 验证必需字段
    const requiredFields: (keyof Omit<OnboardingData, 'user_id'>)[] = [
      'username', 'motivations', 'age', 'currency_code',
      'rough_monthly_income', 'rough_monthly_expenses', 'rough_net_worth', 'desired_lifestyle',
    ]

    for (const field of requiredFields) {
      if (body[field] === undefined || body[field] === null) {
        return new Response(
          JSON.stringify({
            success: false,
            error: { code: 'VALIDATION_ERROR', message: `Missing required field: ${field}`, field },
          }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    }

    // 计算 desired_monthly_expenses
    const lifestyleMultiplier = { simpler: 0.8, current: 1.0, dream: 1.5 }
    const desiredMonthlyExpenses = body.rough_monthly_expenses * (lifestyleMultiplier[body.desired_lifestyle] || 1.0)

    // 检查是否已有 profile
    const { data: existingProfile } = await supabase
      .from('user_profiles')
      .select('id')
      .eq('user_id', userId)
      .maybeSingle()

    if (existingProfile) {
      // 已有 profile，返回已有数据而不是报错
      // 这样用户重新走 onboarding 不会报错
      const fireNumber = desiredMonthlyExpenses * 12 * 25
      const gap = Math.max(fireNumber - body.rough_net_worth, 0)
      const currentSavings = body.rough_monthly_income - body.rough_monthly_expenses
      const currentSavingsRate = currentSavings > 0
        ? (currentSavings / body.rough_monthly_income) * 100
        : 0

      const annualReturn = ASSUMPTIONS.REAL_ANNUAL_RETURN
      const monthlyRate = annualReturn / 12

      let yearsToFire = 0
      if (currentSavings > 0 && gap > 0) {
        const months = Math.log((gap * monthlyRate / currentSavings) + 1) / Math.log(1 + monthlyRate)
        yearsToFire = Math.max(1, Math.ceil(months / 12))
      }

      const freedomAge = body.age + yearsToFire

      return new Response(
        JSON.stringify({
          success: true,
          data: {
            profile: {
              profile_id: existingProfile.id,
              user_id: userId,
              username: body.username,
              onboarding_completed: true,
            },
            fire_summary: {
              fire_number: Math.round(fireNumber * 100) / 100,
              freedom_age: freedomAge,
              years_left: yearsToFire,
              required_savings_rate: Math.round(currentSavingsRate * 100) / 100,
              current_net_worth: body.rough_net_worth,
              gap_to_fire: Math.round(gap * 100) / 100,
              on_track: currentSavingsRate >= 15,
            },
          },
          meta: { timestamp: new Date().toISOString() },
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 插入 user_profiles
    const { data: profile, error: profileError } = await supabase
      .from('user_profiles')
      .insert({
        user_id: userId,
        username: body.username,
        motivations: body.motivations,
        age: body.age,
        currency_code: body.currency_code,
        monthly_income: body.rough_monthly_income,
        current_monthly_expenses: body.rough_monthly_expenses,
        current_net_worth: body.rough_net_worth,
        desired_lifestyle: body.desired_lifestyle,
        onboarding_completed: true,
        onboarding_step: 10,
        timezone: 'America/New_York',
      })
      .select()
      .single()

    if (profileError) {
      console.error('Error creating profile:', profileError)
      return new Response(
        JSON.stringify({
          success: false,
          error: {
            code: 'DATABASE_ERROR',
            message: 'Failed to create user profile',
            details: profileError.message,
          },
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 创建免费订阅
    const { error: subscriptionError } = await supabase
      .from('subscriptions')
      .insert({
        user_id: userId,
        subscription_type: 'free',
        status: 'active',
        started_at: new Date().toISOString(),
      })

    if (subscriptionError) {
      console.error('⚠️ Subscription error:', subscriptionError)
    } else {
      console.log('✅ Created free subscription')
    }

    // 计算 FIRE summary
    const fireNumber = desiredMonthlyExpenses * 12 * 25
    const gap = Math.max(fireNumber - body.rough_net_worth, 0)
    const currentSavings = body.rough_monthly_income - body.rough_monthly_expenses
    const currentSavingsRate = currentSavings > 0
      ? (currentSavings / body.rough_monthly_income) * 100
      : 0

    const annualReturn = ASSUMPTIONS.REAL_ANNUAL_RETURN
    const monthlyRate = annualReturn / 12

    let yearsToFire = 0
    if (currentSavings > 0 && gap > 0) {
      const months = Math.log((gap * monthlyRate / currentSavings) + 1) / Math.log(1 + monthlyRate)
      yearsToFire = Math.max(1, Math.ceil(months / 12))
    }

    const freedomAge = body.age + yearsToFire

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          profile: {
            profile_id: profile.id,
            user_id: userId,
            username: body.username,
            onboarding_completed: true,
          },
          fire_summary: {
            fire_number: Math.round(fireNumber * 100) / 100,
            freedom_age: freedomAge,
            years_left: yearsToFire,
            required_savings_rate: Math.round(currentSavingsRate * 100) / 100,
            current_net_worth: body.rough_net_worth,
            gap_to_fire: Math.round(gap * 100) / 100,
            on_track: currentSavingsRate >= 15,
          },
        },
        meta: { timestamp: new Date().toISOString() },
      }),
      { status: 201, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error:', error)

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