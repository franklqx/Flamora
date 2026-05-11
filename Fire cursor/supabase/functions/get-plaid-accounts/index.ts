import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
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

    // 获取用户所有活跃账户，关联 plaid_items 获取机构名称
    const { data: accounts, error: accountsError } = await supabase
      .from('plaid_accounts')
      .select(`
        id,
        account_id,
        name,
        official_name,
        type,
        subtype,
        mask,
        balance_current,
        balance_available,
        iso_currency_code,
        is_active,
        plaid_items!inner (
          institution_name,
          institution_id,
          institution_logo_base64,
          institution_logo_url,
          institution_primary_color,
          status
        )
      `)
      .eq('user_id', user.id)
      .eq('is_active', true)
      .order('type', { ascending: true })

    if (accountsError) {
      console.error('Error fetching accounts:', accountsError)
      return new Response(
        JSON.stringify({ success: false, error: { code: 'QUERY_ERROR', message: accountsError.message } }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 格式化返回数据
    const formattedAccounts = (accounts || []).map((a: any) => ({
      id: a.id,
      account_id: a.account_id,
      name: a.name,
      official_name: a.official_name,
      type: a.type,
      subtype: a.subtype,
      mask: a.mask,
      balance_current: a.balance_current,
      institution_name: a.plaid_items?.institution_name || null,
      institution_logo_base64: a.plaid_items?.institution_logo_base64 ?? null,
      institution_logo_url: a.plaid_items?.institution_logo_url ?? null,
      institution_primary_color: a.plaid_items?.institution_primary_color ?? null,
      has_transactions: ['depository', 'credit'].includes(a.type),
    }))

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          accounts: formattedAccounts,
          total_accounts: formattedAccounts.length,
          has_transaction_accounts: formattedAccounts.some((a: any) => a.has_transactions),
        },
        meta: { timestamp: new Date().toISOString(), user_id: user.id },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in get-plaid-accounts:', error)
    return new Response(
      JSON.stringify({ success: false, error: { code: 'INTERNAL_SERVER_ERROR', message: error.message || 'An unexpected error occurred' } }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
