// supabase/functions/get-setup-state/index.ts
//
// Returns the current setup stage and resume pointer for a user.
// Drives the S0–S5 Home state machine on iOS.
//
// Stages (in order):
//   no_goal           → No active fire_goal exists
//   goal_set          → Goal exists, no Plaid connection
//   accounts_linked   → Plaid connected, accounts not reviewed
//   snapshot_pending  → Accounts reviewed, financial snapshot not seen
//   plan_pending      → Snapshot seen, no active plan
//   active            → Active plan exists — full Home

import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

type SetupStage =
  | 'no_goal'
  | 'goal_set'
  | 'accounts_linked'
  | 'snapshot_pending'
  | 'plan_pending'
  | 'active'

Deno.serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return errorResponse(401, 'UNAUTHORIZED', 'Missing Authorization header')

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)
    if (authError || !user) return errorResponse(401, 'UNAUTHORIZED', 'Invalid token')

    // ── Parallel fetch ────────────────────────────────────────
    const [goalResult, profileResult, setupStateResult, activePlanResult, accountsResult] = await Promise.all([
      supabase
        .from('fire_goals')
        .select('id, created_at')
        .eq('user_id', user.id)
        .eq('is_active', true)
        .maybeSingle(),
      supabase
        .from('user_profiles')
        .select('has_linked_bank, starting_portfolio_balance, starting_portfolio_source')
        .eq('user_id', user.id)
        .maybeSingle(),
      supabase
        .from('user_setup_state')
        .select('accounts_reviewed_at, snapshot_reviewed_at, plan_applied_at')
        .eq('user_id', user.id)
        .maybeSingle(),
      supabase
        .from('active_plans')
        .select('id, created_at')
        .eq('user_id', user.id)
        .eq('is_active', true)
        .maybeSingle(),
      supabase
        .from('plaid_accounts')
        .select('id, type, balance_current, plaid_items ( institution_name )')
        .eq('user_id', user.id)
        .eq('is_active', true),
    ])

    const activeGoal    = goalResult.data
    const profile       = profileResult.data
    const setupState    = setupStateResult.data
    const activePlan    = activePlanResult.data
    const accounts      = accountsResult.data ?? []

    const cashflowAccounts = accounts.filter((account: any) =>
      account.type === 'depository' || account.type === 'credit'
    )
    const investmentAccounts = accounts.filter((account: any) => account.type === 'investment')

    let hasCashflowTransactions = false
    if (cashflowAccounts.length > 0) {
      const { data: txRows } = await supabase
        .from('transactions')
        .select('id')
        .eq('user_id', user.id)
        .in('plaid_account_id', cashflowAccounts.map((account: any) => account.id))
        .limit(1)

      hasCashflowTransactions = (txRows?.length ?? 0) > 0
    }

    const startingPortfolioSource = profile?.starting_portfolio_source ?? null
    const hasCashflowAccounts = cashflowAccounts.length > 0
    const hasInvestmentAccounts = investmentAccounts.length > 0
    const cashflowComplete = hasCashflowAccounts && hasCashflowTransactions
    const portfolioComplete = hasInvestmentAccounts ||
      startingPortfolioSource === 'manual_estimate' ||
      startingPortfolioSource === 'explicit_zero'
    const monthlyPlanComplete = activePlan != null

    const institutionsFor = (rows: any[]): string[] => {
      const names = rows
        .map((row) => row.plaid_items?.institution_name)
        .filter((name): name is string => typeof name === 'string' && name.length > 0)
      return Array.from(new Set(names))
    }
    const cashflowInstitutionNames = institutionsFor(cashflowAccounts)
    const portfolioInstitutionNames = institutionsFor(investmentAccounts)

    // ── Derive stage ──────────────────────────────────────────
    let stage: SetupStage
    let lastIncompleteStage: SetupStage | null = null

    if (!activeGoal) {
      stage = 'no_goal'
    } else if (!profile?.has_linked_bank) {
      stage = 'goal_set'
      lastIncompleteStage = 'goal_set'
    } else if (!setupState?.accounts_reviewed_at) {
      stage = 'accounts_linked'
      lastIncompleteStage = 'accounts_linked'
    } else if (!setupState?.snapshot_reviewed_at) {
      stage = 'snapshot_pending'
      lastIncompleteStage = 'snapshot_pending'
    } else if (!activePlan) {
      stage = 'plan_pending'
      lastIncompleteStage = 'plan_pending'
    } else {
      stage = 'active'
    }

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          setup_stage:          stage,
          last_incomplete_stage: lastIncompleteStage,

          // Checkpoint timestamps
          goal_completed_at:       activeGoal?.created_at ?? null,
          accounts_reviewed_at:    setupState?.accounts_reviewed_at ?? null,
          snapshot_reviewed_at:    setupState?.snapshot_reviewed_at ?? null,
          plan_applied_at:         setupState?.plan_applied_at ?? activePlan?.created_at ?? null,

          // IDs for deep-linking
          active_plan_id:  activePlan?.id ?? null,
          active_goal_id:  activeGoal?.id ?? null,

          // Explicit Home setup checklist
          cashflow_complete:       cashflowComplete,
          portfolio_complete:      portfolioComplete,
          monthly_plan_complete:   monthlyPlanComplete,
          has_cashflow_accounts:   hasCashflowAccounts,
          has_cashflow_transactions: hasCashflowTransactions,
          has_investment_accounts: hasInvestmentAccounts,
          starting_portfolio_source: startingPortfolioSource,
          cashflow_institution_names: cashflowInstitutionNames,
          portfolio_institution_names: portfolioInstitutionNames,
        },
        meta: { timestamp: new Date().toISOString(), user_id: user.id },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in get-setup-state:', error)
    const message = error instanceof Error ? error.message : 'An unexpected error occurred'
    return errorResponse(500, 'INTERNAL_SERVER_ERROR', message)
  }
})

function errorResponse(status: number, code: string, message: string): Response {
  return new Response(
    JSON.stringify({ success: false, error: { code, message } }),
    { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}
