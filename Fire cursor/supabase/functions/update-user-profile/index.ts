// supabase/functions/update-user-profile/index.ts
//
// Partial update for user_profiles. Used by the manual-mode budget setup
// to keep `monthly_income` / `current_net_worth` / `age` in sync with the
// numbers the user just entered, so downstream readers (Home Hero,
// get-active-fire-goal, generate-plans, etc.) don't see stale onboarding
// estimates.
//
// JWT-authed; only updates fields explicitly supplied in the request body.
// All fields are optional — a no-op body returns the current row.

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface UpdateUserProfileRequest {
  age?: number | null
  monthly_income?: number | null
  current_net_worth?: number | null
  current_monthly_expenses?: number | null
  currency_code?: string | null
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

    let body: UpdateUserProfileRequest = {}
    try {
      body = await req.json()
    } catch (_e) {
      // Empty body is allowed — treat as no-op.
      body = {}
    }

    // Build update payload, omitting any fields the caller didn't send.
    const update: Record<string, unknown> = {}

    if (body.age !== undefined && body.age !== null) {
      const ageNum = Number(body.age)
      if (!Number.isFinite(ageNum) || ageNum <= 0 || ageNum > 120) {
        return jsonError(400, 'INVALID_AGE', 'age must be a positive integer <= 120')
      }
      update.age = Math.round(ageNum)
    }

    if (body.monthly_income !== undefined && body.monthly_income !== null) {
      const income = Number(body.monthly_income)
      if (!Number.isFinite(income) || income < 0) {
        return jsonError(400, 'INVALID_MONTHLY_INCOME', 'monthly_income must be >= 0')
      }
      update.monthly_income = income
    }

    if (body.current_net_worth !== undefined && body.current_net_worth !== null) {
      const nw = Number(body.current_net_worth)
      if (!Number.isFinite(nw)) {
        return jsonError(400, 'INVALID_NET_WORTH', 'current_net_worth must be a finite number')
      }
      update.current_net_worth = nw
    }

    if (body.current_monthly_expenses !== undefined && body.current_monthly_expenses !== null) {
      const exp = Number(body.current_monthly_expenses)
      if (!Number.isFinite(exp) || exp < 0) {
        return jsonError(400, 'INVALID_MONTHLY_EXPENSES', 'current_monthly_expenses must be >= 0')
      }
      update.current_monthly_expenses = exp
    }

    if (body.currency_code !== undefined && body.currency_code !== null) {
      const cc = String(body.currency_code).trim().toUpperCase()
      if (cc.length === 0 || cc.length > 8) {
        return jsonError(400, 'INVALID_CURRENCY_CODE', 'currency_code must be a non-empty string')
      }
      update.currency_code = cc
    }

    // Verify a profile exists. Updates on a missing row would silently
    // affect 0 rows — surface that explicitly so callers can recover.
    const { data: existing, error: existingError } = await supabase
      .from('user_profiles')
      .select('id')
      .eq('user_id', user.id)
      .single()

    if (existingError || !existing) {
      return jsonError(
        404,
        'NO_PROFILE_FOUND',
        'User profile not found. Please complete onboarding first.'
      )
    }

    // No-op update — just return the current row.
    if (Object.keys(update).length === 0) {
      const { data: profile, error: readError } = await supabase
        .from('user_profiles')
        .select('*')
        .eq('user_id', user.id)
        .single()
      if (readError || !profile) {
        return jsonError(500, 'READ_ERROR', 'Failed to read profile')
      }
      return jsonOk(profile, user.id)
    }

    update.updated_at = new Date().toISOString()

    const { data: updated, error: updateError } = await supabase
      .from('user_profiles')
      .update(update)
      .eq('user_id', user.id)
      .select('*')
      .single()

    if (updateError || !updated) {
      console.error('Error updating user profile:', updateError)
      return jsonError(500, 'UPDATE_ERROR', 'Failed to update profile')
    }

    return jsonOk(updated, user.id)
  } catch (error) {
    console.error('Error in update-user-profile:', error)
    return jsonError(
      500,
      'INTERNAL_SERVER_ERROR',
      (error as Error)?.message || 'An unexpected error occurred'
    )
  }
})

function jsonOk(profile: Record<string, unknown>, userId: string): Response {
  return new Response(
    JSON.stringify({
      success: true,
      data: {
        profile_id: profile.id,
        user_id: profile.user_id,
        username: profile.username,
        monthly_income: profile.monthly_income,
        current_net_worth: profile.current_net_worth,
        current_monthly_expenses: profile.current_monthly_expenses,
        currency_code: profile.currency_code,
        timezone: profile.timezone,
        onboarding_completed: profile.onboarding_completed,
        onboarding_step: profile.onboarding_step,
        age: profile.age,
        has_linked_bank: profile.has_linked_bank ?? false,
        plaid_institution_name: profile.plaid_institution_name ?? null,
        plaid_net_worth: profile.plaid_net_worth ?? null,
        created_at: profile.created_at,
        updated_at: profile.updated_at,
      },
      meta: {
        timestamp: new Date().toISOString(),
        user_id: userId,
      },
    }),
    { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}

function jsonError(status: number, code: string, message: string): Response {
  return new Response(
    JSON.stringify({ success: false, error: { code, message } }),
    { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}
