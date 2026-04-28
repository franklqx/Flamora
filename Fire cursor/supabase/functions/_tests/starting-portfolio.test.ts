import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts'
import { pickStartingPortfolio } from '../_shared/starting-portfolio.ts'

Deno.test('starting portfolio: explicit zero wins over connected investment fallback', () => {
  const resolved = pickStartingPortfolio({
    bodyStartingPortfolioBalance: 0,
    bodyStartingPortfolioSource: 'explicit_zero',
    profile: {
      current_net_worth: 12_000,
      plaid_net_worth: 42_000,
      starting_portfolio_balance: null,
      starting_portfolio_source: null,
    },
    connectedInvestmentTotal: 42_000,
  })

  assertEquals(resolved.balance, 0)
  assertEquals(resolved.source, 'explicit_zero')
  assertEquals(resolved.shouldPersistProfile, false)
})

Deno.test('starting portfolio: unknown zero does not mask profile Plaid investments', () => {
  const resolved = pickStartingPortfolio({
    bodyStartingPortfolioBalance: 0,
    bodyStartingPortfolioSource: 'unknown',
    bodyCurrentNetWorth: 0,
    profile: {
      current_net_worth: 0,
      plaid_net_worth: 70_500,
      starting_portfolio_balance: null,
      starting_portfolio_source: null,
    },
  })

  assertEquals(resolved.balance, 70_500)
  assertEquals(resolved.source, 'plaid_investment')
  assertEquals(resolved.shouldPersistProfile, true)
})

Deno.test('starting portfolio: unknown zero falls back to active investment accounts', () => {
  const resolved = pickStartingPortfolio({
    bodyStartingPortfolioBalance: 0,
    bodyStartingPortfolioSource: 'unknown',
    bodyCurrentNetWorth: 0,
    profile: {
      current_net_worth: 0,
      plaid_net_worth: null,
      starting_portfolio_balance: null,
      starting_portfolio_source: null,
    },
    connectedInvestmentTotal: 70_500,
  })

  assertEquals(resolved.balance, 70_500)
  assertEquals(resolved.source, 'plaid_investment')
  assertEquals(resolved.shouldPersistProfile, true)
})
