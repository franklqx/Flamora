// supabase/functions/get-portfolio-history/index.ts
// Returns net_worth_history (investment_total) for the PortfolioCard chart.

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

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', '')
    )
    if (authError || !user) {
      return new Response(
        JSON.stringify({ success: false, error: { code: 'UNAUTHORIZED', message: 'Invalid or expired token' } }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Parse range param: 1w | 1m | 3m | ytd | all (default: 1m)
    const url = new URL(req.url)
    const range = url.searchParams.get('range') ?? '1m'

    const now = new Date()
    let startDate: string

    if (range === 'ytd') {
      startDate = `${now.getFullYear()}-01-01`
    } else if (range === 'all') {
      startDate = '2000-01-01'
    } else {
      const d = new Date(now)
      if (range === '1w')      d.setDate(d.getDate() - 7)
      else if (range === '3m') d.setMonth(d.getMonth() - 3)
      else                     d.setMonth(d.getMonth() - 1)  // 1m default
      startDate = d.toISOString().slice(0, 10)
    }

    const { data: rows, error } = await supabase
      .from('net_worth_history')
      .select('date, investment_total, total_net_worth')
      .eq('user_id', user.id)
      .gte('date', startDate)
      .order('date', { ascending: true })

    if (error) {
      return new Response(
        JSON.stringify({ success: false, error: { code: 'QUERY_ERROR', message: error.message } }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const points = (rows || []).map((r: any) => ({
      date: r.date,
      value: r.investment_total ?? r.total_net_worth ?? 0,
    }))

    return new Response(
      JSON.stringify({ success: true, data: { points, range } }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: { code: 'INTERNAL_SERVER_ERROR', message: error.message } }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
