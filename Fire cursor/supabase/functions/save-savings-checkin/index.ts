import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface SaveSavingsCheckInRequest {
  month?: string
  savings_actual?: number | null
}

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return jsonError(401, 'UNAUTHORIZED', 'Missing Authorization header')
    }

    const supabaseAuth = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error: authError } = await supabaseAuth.auth.getUser()
    if (authError || !user) {
      return jsonError(401, 'UNAUTHORIZED', 'Invalid or expired token')
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const body: SaveSavingsCheckInRequest = await req.json()
    const normalizedMonth = normalizeMonth(body.month)
    if (!normalizedMonth) {
      return jsonError(400, 'INVALID_MONTH', 'month must be YYYY-MM or YYYY-MM-01')
    }

    const savingsActual = normalizeSavingsActual(body.savings_actual)
    if (body.savings_actual !== undefined && body.savings_actual !== null && savingsActual === null) {
      return jsonError(400, 'INVALID_AMOUNT', 'savings_actual must be >= 0')
    }

    const { data: existingBudget, error: budgetError } = await supabase
      .from('budgets')
      .select('*')
      .eq('user_id', user.id)
      .eq('month', normalizedMonth)
      .single()

    if (budgetError || !existingBudget) {
      return jsonError(404, 'NO_BUDGET_FOUND', `No budget found for ${normalizedMonth.slice(0, 7)}`)
    }

    const { data: updatedBudget, error: updateError } = await supabase
      .from('budgets')
      .update({
        savings_actual: savingsActual,
        updated_at: new Date().toISOString(),
      })
      .eq('id', existingBudget.id)
      .select('*')
      .single()

    if (updateError || !updatedBudget) {
      console.error('Error updating savings check-in:', updateError)
      return jsonError(500, 'UPDATE_ERROR', 'Failed to save savings check-in')
    }

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          budget_id: updatedBudget.id,
          month: updatedBudget.month,
          needs_budget: updatedBudget.needs_budget,
          wants_budget: updatedBudget.wants_budget,
          savings_budget: updatedBudget.savings_budget,
          needs_spent: updatedBudget.needs_spent,
          wants_spent: updatedBudget.wants_spent,
          savings_actual: updatedBudget.savings_actual,
          needs_ratio: updatedBudget.needs_ratio,
          wants_ratio: updatedBudget.wants_ratio,
          savings_ratio: updatedBudget.savings_ratio,
          selected_plan: updatedBudget.selected_plan || null,
          is_custom: updatedBudget.is_custom,
        },
        meta: {
          timestamp: new Date().toISOString(),
          user_id: user.id,
        },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in save-savings-checkin:', error)
    return jsonError(500, 'INTERNAL_SERVER_ERROR', error.message || 'An unexpected error occurred')
  }
})

function normalizeMonth(input?: string | null): string | null {
  if (!input) {
    return `${new Date().toISOString().slice(0, 7)}-01`
  }
  if (/^\d{4}-\d{2}$/.test(input)) {
    return `${input}-01`
  }
  if (/^\d{4}-\d{2}-\d{2}$/.test(input)) {
    return input.slice(0, 7) + '-01'
  }
  return null
}

function normalizeSavingsActual(input?: number | null): number | null {
  if (input === undefined || input === null) return null
  if (!Number.isFinite(input) || input < 0) return null
  return input > 0 ? Number(input.toFixed(2)) : null
}

function jsonError(status: number, code: string, message: string) {
  return new Response(
    JSON.stringify({ success: false, error: { code, message } }),
    { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}
