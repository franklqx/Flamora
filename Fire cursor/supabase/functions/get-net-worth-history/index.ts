// supabase/functions/get-net-worth-history/index.ts
//
// Returns total_net_worth time-series for the Home NetWorth card / detail chart.
// Source of truth: `net_worth_history` (daily snapshots written by handle-plaid-webhook
// on INITIAL_UPDATE / DEFAULT_UPDATE / HISTORICAL_UPDATE / disconnect-bank).
//
// Ranges accepted (kept aligned with iOS `NetWorthRange`):
//   1w | 1m | 3m | 1y | all   (default: 1m)
//
// NOTE on single-point days: we deliberately return points as-is (no synthetic
// duplication) so the iOS card can fall through to its empty-state placeholder
// until the user has at least 2 days of history. This keeps Day-1 honest.

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

    const url = new URL(req.url)
    const range = (url.searchParams.get('range') ?? '1m').toLowerCase()

    const now = new Date()
    let startDate: string
    if (range === 'all') {
      startDate = '2000-01-01'
    } else {
      const d = new Date(now)
      switch (range) {
        case '1w': d.setDate(d.getDate() - 7); break
        case '3m': d.setMonth(d.getMonth() - 3); break
        case '1y': d.setFullYear(d.getFullYear() - 1); break
        case '1m':
        default:   d.setMonth(d.getMonth() - 1); break
      }
      startDate = d.toISOString().slice(0, 10)
    }

    const { data: rows, error } = await supabase
      .from('net_worth_history')
      .select('date, total_net_worth, investment_total, depository_total')
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
      value: Number(r.total_net_worth ?? 0),
    }))

    return new Response(
      JSON.stringify({
        success: true,
        data: { points, range },
        meta: { timestamp: new Date().toISOString(), user_id: user.id, count: points.length },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: { code: 'INTERNAL_SERVER_ERROR', message: (error as Error).message } }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
