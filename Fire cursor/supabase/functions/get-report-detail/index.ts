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
    const id = url.searchParams.get('id')
    const kind = url.searchParams.get('kind')
    const latest = url.searchParams.get('latest') === 'true'

    let query = supabase
      .from('report_snapshots')
      .select('*')
      .eq('user_id', user.id)
      .eq('status', 'ready')
      .order('generated_at', { ascending: false })
      .limit(1)

    if (id) {
      query = supabase
        .from('report_snapshots')
        .select('*')
        .eq('user_id', user.id)
        .eq('id', id)
        .eq('status', 'ready')
        .limit(1)
    } else if (kind && latest) {
      query = query.eq('kind', kind)
    } else {
      return errorResponse(400, 'BAD_REQUEST', 'Provide id, or kind with latest=true')
    }

    const { data, error } = await query.maybeSingle()
    if (error) return errorResponse(500, 'QUERY_ERROR', error.message)
    if (!data) return errorResponse(404, 'NOT_FOUND', 'Report not found')

    const payload = {
      id: data.id,
      user_id: data.user_id,
      kind: data.kind,
      status: data.status,
      title: data.title,
      period: {
        start: data.period_start,
        end: data.period_end,
        label: data.period_label,
      },
      generated_at: data.generated_at,
      viewed_at: data.viewed_at,
      insight_text: data.insight_text,
      insight_provider: data.insight_provider,
      metrics_payload: stringifyMetrics(data.metrics_payload),
      story_payload: data.story_payload ?? [],
    }

    return new Response(
      JSON.stringify({
        success: true,
        data: payload,
        meta: { timestamp: new Date().toISOString(), user_id: user.id },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in get-report-detail:', error)
    return errorResponse(500, 'INTERNAL_SERVER_ERROR', error.message)
  }
})

function stringifyMetrics(metrics: Record<string, unknown> | null) {
  const result: Record<string, string> = {}
  for (const [key, value] of Object.entries(metrics ?? {})) {
    result[key] = String(value)
  }
  return result
}

function errorResponse(status: number, code: string, message: string) {
  return new Response(
    JSON.stringify({ success: false, error: { code, message } }),
    { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}
