// supabase/functions/create-link-token/index.ts

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
        JSON.stringify({
          success: false,
          error: { code: 'UNAUTHORIZED', message: 'Missing Authorization header' },
        }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 用 anon key 初始化客户端（验证 JWT）
    const supabaseAuth = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error: authError } = await supabaseAuth.auth.getUser()
    if (authError || !user) {
      return new Response(
        JSON.stringify({
          success: false,
          error: { code: 'UNAUTHORIZED', message: 'Invalid or expired token' },
        }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 用 service role key 初始化客户端（绕过 RLS，读写数据）
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // ============================================================
    // 2. Premium 校验（Paywall 门控）
    // ============================================================
    const { data: subscription, error: subError } = await supabase
      .from('subscriptions')
      .select('status, subscription_type')
      .eq('user_id', user.id)
      .single()

    const isPremium = subscription?.status === 'active' 
      && subscription?.subscription_type !== 'free'

    if (subError || !isPremium) {
      return new Response(
        JSON.stringify({
          success: false,
          error: {
            code: 'PREMIUM_REQUIRED',
            message: 'Bank linking requires a Premium subscription. Please upgrade to connect your accounts.',
          },
        }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ============================================================
    // 3. 调用 Plaid API 创建 Link Token
    // ============================================================
    const plaidClientId = Deno.env.get('PLAID_CLIENT_ID')
    const plaidSecret = Deno.env.get('PLAID_SECRET')
    const plaidEnv = Deno.env.get('PLAID_ENV') || 'sandbox'

    if (!plaidClientId || !plaidSecret) {
      console.error('Missing Plaid credentials')
      return new Response(
        JSON.stringify({
          success: false,
          error: { code: 'SERVER_CONFIG_ERROR', message: 'Plaid API is not configured' },
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Plaid 环境 URL
    const plaidBaseUrl = plaidEnv === 'production'
      ? 'https://production.plaid.com'
      : 'https://sandbox.plaid.com'

    // Webhook URL（Plaid 推送交易/投资更新）
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const webhookUrl = `${supabaseUrl}/functions/v1/handle-plaid-webhook`

    const plaidResponse = await fetch(`${plaidBaseUrl}/link/token/create`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        client_id: plaidClientId,
        secret: plaidSecret,
        user: {
          client_user_id: user.id,
        },
        client_name: 'Flamora',
        products: ['transactions'],
        optional_products: ['investments'],
        country_codes: ['US'],
        language: 'en',
        webhook: webhookUrl,
        transactions: {
          days_requested: 730, // 24 个月历史交易
        },
      }),
    })

    const plaidData = await plaidResponse.json()

    if (!plaidResponse.ok) {
      console.error('Plaid API error:', JSON.stringify(plaidData))
      return new Response(
        JSON.stringify({
          success: false,
          error: {
            code: 'PLAID_API_ERROR',
            message: plaidData.error_message || 'Failed to create Link token',
            plaid_error_code: plaidData.error_code,
            plaid_error_type: plaidData.error_type,
          },
        }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ============================================================
    // 4. 返回 Link Token
    // ============================================================
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          link_token: plaidData.link_token,
          expiration: plaidData.expiration,
          request_id: plaidData.request_id,
        },
        meta: {
          timestamp: new Date().toISOString(),
          user_id: user.id,
        },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in create-link-token:', error)

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