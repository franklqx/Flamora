import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders, handleCors } from '../_shared/cors.ts'

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

    const body = await req.json()
    const transactionId = typeof body?.transaction_id === 'string' ? body.transaction_id : ''
    const flamoraCategory = typeof body?.flamora_category === 'string' ? body.flamora_category : null
    const flamoraSubcategory = typeof body?.flamora_subcategory === 'string' ? body.flamora_subcategory : null

    if (!transactionId) {
      return new Response(
        JSON.stringify({ success: false, error: { code: 'VALIDATION_ERROR', message: 'transaction_id is required' } }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (flamoraCategory && !['needs', 'wants', 'income', 'transfer'].includes(flamoraCategory)) {
      return new Response(
        JSON.stringify({ success: false, error: { code: 'VALIDATION_ERROR', message: 'Invalid flamora_category' } }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const updatePayload: Record<string, string | boolean | null> = {
      pending_review: false,
    }
    if (flamoraCategory !== null) updatePayload.flamora_category = flamoraCategory
    if (flamoraSubcategory !== null) updatePayload.flamora_subcategory = flamoraSubcategory

    const { data, error } = await supabase
      .from('transactions')
      .update(updatePayload)
      .eq('id', transactionId)
      .eq('user_id', user.id)
      .select('id, merchant_name, name, amount, date, pending_review, flamora_category, flamora_subcategory, plaid_account_id')
      .single()

    if (error) {
      return new Response(
        JSON.stringify({ success: false, error: { code: 'QUERY_ERROR', message: error.message } }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!data) {
      return new Response(
        JSON.stringify({ success: false, error: { code: 'NOT_FOUND', message: 'Transaction not found' } }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify({
        success: true,
        data,
        meta: { timestamp: new Date().toISOString(), user_id: user.id },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: { code: 'INTERNAL_SERVER_ERROR', message: error.message || 'Unexpected error' } }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
