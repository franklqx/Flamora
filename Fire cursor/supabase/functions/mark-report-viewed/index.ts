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

    const body = await req.json()
    const reportId = body.report_id as string
    if (!reportId) return errorResponse(400, 'BAD_REQUEST', 'report_id is required')

    const now = new Date().toISOString()

    const { data: report, error } = await supabase
      .from('report_snapshots')
      .update({ viewed_at: now, updated_at: now })
      .eq('user_id', user.id)
      .eq('id', reportId)
      .select('id, kind, viewed_at')
      .single()

    if (error) return errorResponse(500, 'UPDATE_ERROR', error.message)

    if (report.kind === 'issue_zero') {
      await supabase
        .from('user_setup_state')
        .upsert(
          {
            user_id: user.id,
            issue_zero_viewed_at: now,
            updated_at: now,
          },
          { onConflict: 'user_id' }
        )
    }

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          report_id: report.id,
          viewed_at: report.viewed_at,
        },
        meta: { timestamp: now, user_id: user.id },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in mark-report-viewed:', error)
    return errorResponse(500, 'INTERNAL_SERVER_ERROR', error.message)
  }
})

function errorResponse(status: number, code: string, message: string) {
  return new Response(
    JSON.stringify({ success: false, error: { code, message } }),
    { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}
