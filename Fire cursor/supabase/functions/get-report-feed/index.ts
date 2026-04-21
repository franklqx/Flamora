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
    const limit = Math.min(Number(url.searchParams.get('limit') ?? '12'), 25)
    const kind = url.searchParams.get('kind')

    let query = supabase
      .from('report_snapshots')
      .select('id, kind, title, period_label, generated_at, viewed_at, status')
      .eq('user_id', user.id)
      .eq('status', 'ready')
      .order('generated_at', { ascending: false })
      .limit(limit)

    if (kind) query = query.eq('kind', kind)

    const { data, error } = await query
    if (error) return errorResponse(500, 'QUERY_ERROR', error.message)

    const items = (data ?? [])
      .map((row: any) => ({
        id: `${row.id}-feed`,
        report_id: row.id,
        kind: row.kind,
        title: row.title,
        subtitle: subtitleForKind(row.kind, row.period_label),
        period_label: row.period_label,
        generated_at: row.generated_at,
        viewed_at: row.viewed_at,
        is_unread: row.viewed_at == null,
        status: row.status,
      }))
      .sort((a: any, b: any) => {
        if (a.is_unread !== b.is_unread) return a.is_unread ? -1 : 1
        return String(b.generated_at).localeCompare(String(a.generated_at))
      })

    return new Response(
      JSON.stringify({
        success: true,
        data: items,
        meta: { timestamp: new Date().toISOString(), user_id: user.id },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in get-report-feed:', error)
    return errorResponse(500, 'INTERNAL_SERVER_ERROR', error.message)
  }
})

function subtitleForKind(kind: string, periodLabel: string) {
  switch (kind) {
    case 'weekly': return `Your latest weekly story for ${periodLabel}`
    case 'monthly': return `Your FIRE progress for ${periodLabel}`
    case 'annual': return `Your year-in-review for ${periodLabel}`
    case 'issue_zero': return 'Your first look at the numbers'
    default: return periodLabel
  }
}

function errorResponse(status: number, code: string, message: string) {
  return new Response(
    JSON.stringify({ success: false, error: { code, message } }),
    { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}
