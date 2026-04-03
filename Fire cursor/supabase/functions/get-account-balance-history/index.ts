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

    const url = new URL(req.url)
    const accountId = url.searchParams.get('account_id')
    const range = url.searchParams.get('range') ?? '1m'

    if (!accountId) {
      return new Response(
        JSON.stringify({ success: false, error: { code: 'BAD_REQUEST', message: 'Missing account_id' } }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    let startDate: string
    const now = new Date()
    const d = new Date(now)
    switch (range) {
      case '1w':
        d.setDate(d.getDate() - 7)
        startDate = d.toISOString().slice(0, 10)
        break
      case '3m':
        d.setMonth(d.getMonth() - 3)
        startDate = d.toISOString().slice(0, 10)
        break
      case '1y':
        d.setFullYear(d.getFullYear() - 1)
        startDate = d.toISOString().slice(0, 10)
        break
      case 'all':
        startDate = '2000-01-01'
        break
      case '1m':
      default:
        d.setMonth(d.getMonth() - 1)
        startDate = d.toISOString().slice(0, 10)
        break
    }

    const { data: account, error: accountError } = await supabase
      .from('plaid_accounts')
      .select(`
        id,
        name,
        official_name,
        type,
        subtype,
        mask,
        balance_current,
        balance_available,
        plaid_items ( institution_name )
      `)
      .eq('id', accountId)
      .eq('user_id', user.id)
      .single()

    if (accountError || !account) {
      return new Response(
        JSON.stringify({ success: false, error: { code: 'NOT_FOUND', message: 'Account not found' } }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { data: rows, error: historyError } = await supabase
      .from('account_balance_history')
      .select('date, current_balance, available_balance')
      .eq('user_id', user.id)
      .eq('plaid_account_id', accountId)
      .gte('date', startDate)
      .order('date', { ascending: true })

    if (historyError) {
      return new Response(
        JSON.stringify({ success: false, error: { code: 'QUERY_ERROR', message: historyError.message } }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    let points = (rows || []).map((row: any) => ({
      date: row.date,
      current_balance: row.current_balance ?? 0,
      available_balance: row.available_balance,
    }))

    if (points.length === 0) {
      const today = new Date().toISOString().slice(0, 10)
      points = [{
        date: today,
        current_balance: account.balance_current ?? 0,
        available_balance: account.balance_available ?? null,
      }]
    }

    if (points.length == 1) {
      const p = points[0]
      const prior = new Date(`${p.date}T00:00:00Z`)
      prior.setDate(prior.getDate() - 1)
      points = [
        {
          date: prior.toISOString().slice(0, 10),
          current_balance: p.current_balance,
          available_balance: p.available_balance,
        },
        p,
      ]
    }

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          account: {
            id: account.id,
            name: account.name || account.official_name || '',
            type: account.type,
            subtype: account.subtype ?? null,
            mask: account.mask ?? null,
            institution_name: account.plaid_items?.institution_name ?? null,
          },
          points,
          range,
        },
        meta: {
          timestamp: new Date().toISOString(),
          user_id: user.id,
        },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in get-account-balance-history:', error)
    return new Response(
      JSON.stringify({ success: false, error: { code: 'INTERNAL_SERVER_ERROR', message: error.message || 'An unexpected error occurred' } }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
