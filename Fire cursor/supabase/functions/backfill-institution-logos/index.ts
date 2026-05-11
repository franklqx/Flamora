// supabase/functions/backfill-institution-logos/index.ts
//
// One-shot backfill: walks plaid_items where institution_logo_base64 is null
// and fills in logo + primary_color via Plaid /institutions/get_by_id.
//
// Auth: caller must pass a valid Supabase auth token. Only that user's items
// are processed. Safe to re-run — already-populated rows are skipped.
//
// Optional query params:
//   ?force=true       — refetch even if logo is already cached
//   ?limit=100        — max items to process this invocation (default 50)

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { fetchInstitutionBranding, brandingPatch } from '../_shared/institution-logo.ts'

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
    const force = url.searchParams.get('force') === 'true'
    const limit = Math.min(parseInt(url.searchParams.get('limit') ?? '50', 10) || 50, 200)

    const plaidClientId = Deno.env.get('PLAID_CLIENT_ID')!
    const plaidSecret = Deno.env.get('PLAID_SECRET')!
    const plaidEnv = Deno.env.get('PLAID_ENV') || 'sandbox'
    const plaidBaseUrl = plaidEnv === 'production'
      ? 'https://production.plaid.com'
      : 'https://sandbox.plaid.com'

    // Pull candidate items. We dedupe by institution_id below so two items
    // pointing at the same bank only cost one Plaid call.
    let query = supabase
      .from('plaid_items')
      .select('id, institution_id, institution_name, institution_logo_base64')
      .eq('user_id', user.id)
      .not('institution_id', 'is', null)
      .limit(limit)

    if (!force) {
      query = query.is('institution_logo_base64', null)
    }

    const { data: items, error: queryError } = await query
    if (queryError) {
      console.error('[backfill-logos] Query error:', queryError)
      return new Response(
        JSON.stringify({ success: false, error: { code: 'QUERY_ERROR', message: queryError.message } }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const rows = items ?? []
    let updated = 0
    let skipped = 0
    let failed = 0

    // Dedupe Plaid calls per institution_id
    const brandingCache = new Map<string, Awaited<ReturnType<typeof fetchInstitutionBranding>>>()

    for (const item of rows) {
      if (!item.institution_id) {
        skipped += 1
        continue
      }

      let branding = brandingCache.get(item.institution_id)
      if (branding === undefined) {
        branding = await fetchInstitutionBranding(item.institution_id, {
          plaidClientId,
          plaidSecret,
          plaidBaseUrl,
        })
        brandingCache.set(item.institution_id, branding)
      }

      if (!branding) {
        failed += 1
        continue
      }

      const { error: updateError } = await supabase
        .from('plaid_items')
        .update(brandingPatch(branding))
        .eq('id', item.id)

      if (updateError) {
        console.error(`[backfill-logos] Update error for item ${item.id}:`, updateError)
        failed += 1
      } else {
        updated += 1
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          processed: rows.length,
          updated,
          skipped,
          failed,
          unique_institutions: brandingCache.size,
        },
        meta: { timestamp: new Date().toISOString(), user_id: user.id },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('[backfill-logos] Unexpected error:', error)
    return new Response(
      JSON.stringify({ success: false, error: { code: 'INTERNAL_SERVER_ERROR', message: error.message || 'An unexpected error occurred' } }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
