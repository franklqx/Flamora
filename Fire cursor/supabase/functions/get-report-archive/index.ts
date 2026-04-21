import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

Deno.serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return errorResponse(401, 'UNAUTHORIZED', 'Missing Authorization header')

    const supabaseAuth = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    )
    const { data: { user }, error: authError } = await supabaseAuth.auth.getUser()
    if (authError || !user) return errorResponse(401, 'UNAUTHORIZED', 'Invalid token')

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const url = new URL(req.url)
    const limit = Math.min(Number(url.searchParams.get('limit') ?? '20'), 50)
    const cursor = Number(url.searchParams.get('cursor') ?? '0')
    const kind = url.searchParams.get('kind')
    const year = url.searchParams.get('year')

    let query = supabase
      .from('report_snapshots')
      .select('id, kind, title, period_label, generated_at, viewed_at, status')
      .eq('user_id', user.id)
      .eq('status', 'ready')
      .order('generated_at', { ascending: false })
      .range(cursor, cursor + limit - 1)

    if (kind) query = query.eq('kind', kind)
    if (year) query = query.gte('period_start', `${year}-01-01`).lte('period_end', `${year}-12-31`)

    const { data, error } = await query
    if (error) return errorResponse(500, 'QUERY_ERROR', error.message)

    const items = (data ?? [])
      .filter((row: any) => row.viewed_at != null)
      .map((row: any) => ({
      id: `${row.id}-archive`,
      report_id: row.id,
      kind: row.kind,
      title: row.title,
      subtitle: subtitleForKind(row.kind, row.period_label),
      period_label: row.period_label,
      generated_at: row.generated_at,
      viewed_at: row.viewed_at,
      is_unread: false,
      status: row.status,
    }))

    return new Response(
      JSON.stringify({
        success: true,
        data: items,
        meta: { timestamp: new Date().toISOString(), user_id: user.id, next_cursor: cursor + items.length },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in get-report-archive:', error)
    return errorResponse(500, 'INTERNAL_SERVER_ERROR', error.message)
  }
})

function subtitleForKind(kind: string, periodLabel: string) {
  switch (kind) {
    case 'weekly': return `Weekly recap · ${periodLabel}`
    case 'monthly': return `Monthly story · ${periodLabel}`
    case 'annual': return `Annual wrap · ${periodLabel}`
    case 'issue_zero': return 'Your first financial snapshot'
    default: return periodLabel
  }
}

function errorResponse(status: number, code: string, message: string) {
  return new Response(
    JSON.stringify({ success: false, error: { code, message } }),
    { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}
