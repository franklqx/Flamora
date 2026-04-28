export interface StartingPortfolioProfile {
  current_net_worth: number | null
  plaid_net_worth: number | null
  starting_portfolio_balance: number | null
  starting_portfolio_source: string | null
}

export interface StartingPortfolioPickInput {
  bodyStartingPortfolioBalance?: number | null
  bodyStartingPortfolioSource?: string | null
  bodyCurrentNetWorth?: number | null
  profile?: StartingPortfolioProfile | null
  connectedInvestmentTotal?: number | null
}

export interface StartingPortfolioResolution {
  balance: number
  source: string
  shouldPersistProfile: boolean
}

function usableNumber(value: number | null | undefined): value is number {
  return typeof value === 'number' && Number.isFinite(value) && value >= 0
}

function positiveNumber(value: number | null | undefined): value is number {
  return usableNumber(value) && value > 0
}

function cleanSource(source: string | null | undefined): string | null {
  const trimmed = source?.trim()
  return trimmed && trimmed.length > 0 ? trimmed : null
}

export function pickStartingPortfolio(input: StartingPortfolioPickInput): StartingPortfolioResolution {
  const bodySource = cleanSource(input.bodyStartingPortfolioSource)
  const profileSource = cleanSource(input.profile?.starting_portfolio_source)

  if (bodySource === 'explicit_zero') {
    return { balance: 0, source: 'explicit_zero', shouldPersistProfile: false }
  }

  if (positiveNumber(input.bodyStartingPortfolioBalance)) {
    return {
      balance: input.bodyStartingPortfolioBalance,
      source: bodySource ?? 'unknown',
      shouldPersistProfile: false,
    }
  }

  if (positiveNumber(input.bodyCurrentNetWorth)) {
    return {
      balance: input.bodyCurrentNetWorth,
      source: bodySource ?? 'unknown',
      shouldPersistProfile: false,
    }
  }

  if (positiveNumber(input.profile?.starting_portfolio_balance)) {
    return {
      balance: input.profile.starting_portfolio_balance,
      source: profileSource ?? 'unknown',
      shouldPersistProfile: false,
    }
  }

  if (positiveNumber(input.profile?.plaid_net_worth)) {
    return {
      balance: input.profile.plaid_net_worth,
      source: 'plaid_investment',
      shouldPersistProfile: true,
    }
  }

  if (positiveNumber(input.connectedInvestmentTotal)) {
    return {
      balance: input.connectedInvestmentTotal,
      source: 'plaid_investment',
      shouldPersistProfile: true,
    }
  }

  if (positiveNumber(input.profile?.current_net_worth)) {
    return {
      balance: input.profile.current_net_worth,
      source: profileSource ?? 'unknown',
      shouldPersistProfile: false,
    }
  }

  if (usableNumber(input.bodyStartingPortfolioBalance)) {
    return {
      balance: input.bodyStartingPortfolioBalance,
      source: bodySource ?? profileSource ?? 'unknown',
      shouldPersistProfile: false,
    }
  }

  if (usableNumber(input.bodyCurrentNetWorth)) {
    return {
      balance: input.bodyCurrentNetWorth,
      source: bodySource ?? profileSource ?? 'unknown',
      shouldPersistProfile: false,
    }
  }

  if (usableNumber(input.profile?.starting_portfolio_balance)) {
    return {
      balance: input.profile.starting_portfolio_balance,
      source: profileSource ?? 'unknown',
      shouldPersistProfile: false,
    }
  }

  if (usableNumber(input.profile?.current_net_worth)) {
    return {
      balance: input.profile.current_net_worth,
      source: profileSource ?? 'unknown',
      shouldPersistProfile: false,
    }
  }

  return { balance: 0, source: bodySource ?? profileSource ?? 'unknown', shouldPersistProfile: false }
}

export async function fetchActiveInvestmentAccountTotal(supabase: any, userId: string): Promise<number | null> {
  const { data, error } = await supabase
    .from('plaid_accounts')
    .select('balance_current')
    .eq('user_id', userId)
    .eq('is_active', true)
    .eq('type', 'investment')

  if (error) {
    console.warn('[starting-portfolio] failed to fetch investment accounts:', error)
    return null
  }

  return (data ?? []).reduce((sum: number, account: any) => {
    const balance = Number(account?.balance_current ?? 0)
    return sum + (Number.isFinite(balance) ? Math.max(0, balance) : 0)
  }, 0)
}
