import { computeFireDate, computeFireNumber } from './fire-math.ts'
import { ASSUMPTIONS } from './fire-assumptions.ts'

export type ReportKind = 'weekly' | 'monthly' | 'annual' | 'issue_zero'
type ReportStatus = 'pending' | 'ready' | 'failed'

type StoryBackground = 'purple' | 'green' | 'amber' | 'blue' | 'dark'
type HeroStyle = 'gradient_fire' | 'success' | 'warning' | 'error' | 'primary' | 'secondary'
type StoryLayout = 'hero' | 'insight' | 'grid' | 'headline' | 'cta'
type HeroFont = 'storyHero' | 'h1' | 'h2' | 'cardFigurePrimary'

interface StoryMetricRow {
  id: string
  label: string
  value: string
  note?: string | null
  value_style?: HeroStyle | null
}

interface StoryGridItem {
  id: string
  label: string
  value: string
}

interface StoryPayload {
  id: string
  layout: StoryLayout
  label?: string | null
  background: StoryBackground
  hero_text?: string | null
  hero_subtext?: string | null
  hero_style?: HeroStyle | null
  hero_font?: HeroFont | null
  badge_text?: string | null
  rows: StoryMetricRow[]
  grid_items: StoryGridItem[]
  insight_text?: string | null
  insight_source?: string | null
  cta_label?: string | null
}

interface ReportWindow {
  kind: ReportKind
  periodStart: string
  periodEnd: string
  periodLabel: string
}

interface ReportSnapshotDraft {
  kind: ReportKind
  status: ReportStatus
  title: string
  period_start: string
  period_end: string
  period_label: string
  story_payload: StoryPayload[]
  metrics_payload: Record<string, string>
  insight_text: string | null
  insight_provider: string | null
  generated_at: string | null
}

interface UserContext {
  age: number | null
  currentNetWorth: number
  fireNumber: number
  monthlySavingsTarget: number
  officialFireDate: string | null
  officialFireAge: number | null
}

interface TxRow {
  amount: number
  date: string
  flamora_category: string | null
  flamora_subcategory: string | null
  merchant_name: string | null
  name: string | null
}

const INSIGHT_PROVIDER = 'Groq · Llama 3.3'

export function deriveReportWindow(kind: ReportKind, now = new Date()): ReportWindow {
  const today = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()))

  if (kind === 'monthly') {
    const end = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), 0))
    const start = new Date(Date.UTC(end.getUTCFullYear(), end.getUTCMonth(), 1))
    return {
      kind,
      periodStart: toISODate(start),
      periodEnd: toISODate(end),
      periodLabel: formatMonthYear(end),
    }
  }

  if (kind === 'annual') {
    const year = today.getUTCFullYear() - 1
    return {
      kind,
      periodStart: `${year}-01-01`,
      periodEnd: `${year}-12-31`,
      periodLabel: `${year}`,
    }
  }

  if (kind === 'weekly') {
    const day = today.getUTCDay()
    const diffToMonday = (day + 6) % 7
    const currentWeekMonday = addDays(today, -diffToMonday)
    const end = addDays(currentWeekMonday, -1)
    const start = addDays(end, -6)
    return {
      kind,
      periodStart: toISODate(start),
      periodEnd: toISODate(end),
      periodLabel: `${formatShortDate(start)} – ${formatShortDate(end)}`,
    }
  }

  const end = today
  const start = addDays(end, -179)
  return {
    kind,
    periodStart: toISODate(start),
    periodEnd: toISODate(end),
    periodLabel: 'First snapshot',
  }
}

export async function upsertReportSnapshot(
  supabase: any,
  userId: string,
  draft: ReportSnapshotDraft
) {
  const payload = {
    user_id: userId,
    kind: draft.kind,
    period_start: draft.period_start,
    period_end: draft.period_end,
    period_label: draft.period_label,
    title: draft.title,
    status: draft.status,
    story_payload: draft.story_payload,
    metrics_payload: draft.metrics_payload,
    insight_text: draft.insight_text,
    insight_provider: draft.insight_provider,
    generated_at: draft.generated_at,
    updated_at: new Date().toISOString(),
  }

  const { data, error } = await supabase
    .from('report_snapshots')
    .upsert(payload, { onConflict: 'user_id,kind,period_start,period_end' })
    .select()
    .single()

  if (error) throw error
  return data
}

export async function generateReportForUser(
  supabase: any,
  userId: string,
  kind: ReportKind,
  overrides?: Partial<ReportWindow>
): Promise<ReportSnapshotDraft> {
  const baseWindow = deriveReportWindow(kind)
  const window: ReportWindow = {
    ...baseWindow,
    ...overrides,
    kind,
  }

  const context = await fetchUserContext(supabase, userId)

  switch (kind) {
    case 'weekly':
      return await buildWeeklyReport(supabase, userId, context, window)
    case 'monthly':
      return await buildMonthlyReport(supabase, userId, context, window)
    case 'annual':
      return await buildAnnualReport(supabase, userId, context, window)
    case 'issue_zero':
      return await buildIssueZeroReport(supabase, userId, context, window)
  }
}

export async function ensureIssueZeroReport(supabase: any, userId: string) {
  const now = new Date().toISOString()
  const { data: state } = await supabase
    .from('user_setup_state')
    .select('first_bank_connected_at, issue_zero_generated_at')
    .eq('user_id', userId)
    .maybeSingle()

  const firstConnectedAt = state?.first_bank_connected_at ?? now
  const draft = await generateReportForUser(
    supabase,
    userId,
    'issue_zero',
    {
      periodStart: toISODate(addDays(new Date(firstConnectedAt), -179)),
      periodEnd: toISODate(new Date()),
      periodLabel: 'First snapshot',
    }
  )

  const row = await upsertReportSnapshot(supabase, userId, draft)

  if (draft.status === 'ready') {
    await supabase
      .from('user_setup_state')
      .upsert(
        {
          user_id: userId,
          first_bank_connected_at: firstConnectedAt,
          issue_zero_generated_at: now,
          updated_at: now,
        },
        { onConflict: 'user_id' }
      )
  }

  return row
}

export async function stampFirstBankConnectedAt(supabase: any, userId: string) {
  const { data: existing } = await supabase
    .from('user_setup_state')
    .select('first_bank_connected_at')
    .eq('user_id', userId)
    .maybeSingle()

  if (existing?.first_bank_connected_at) return existing.first_bank_connected_at

  const now = new Date().toISOString()
  await supabase
    .from('user_setup_state')
    .upsert(
      {
        user_id: userId,
        first_bank_connected_at: now,
        updated_at: now,
      },
      { onConflict: 'user_id' }
    )

  return now
}

async function buildWeeklyReport(supabase: any, userId: string, context: UserContext, window: ReportWindow): Promise<ReportSnapshotDraft> {
  const transactions = await fetchTransactions(supabase, userId, window.periodStart, window.periodEnd)
  if (transactions.length < 3) {
    return pendingDraft('weekly', 'Weekly Report', window, 'Waiting for more weekly transaction data.')
  }

  const comparison = derivePreviousWindow(window)
  const currentSummary = summarizeTransactions(transactions)
  const previousSummary = summarizeTransactions(
    await fetchTransactions(supabase, userId, comparison.periodStart, comparison.periodEnd)
  )

  const currentNW = await getNetWorthAtOrNear(supabase, userId, window.periodEnd, context.currentNetWorth)
  const previousNW = await getNetWorthAtOrNear(supabase, userId, comparison.periodEnd, currentNW)

  const currentFire = computeFireDate(currentNW, context.fireNumber, context.monthlySavingsTarget || Math.max(currentSummary.saved, 1), ASSUMPTIONS.REAL_ANNUAL_RETURN, context.age ?? undefined)
  const previousFire = computeFireDate(previousNW, context.fireNumber, context.monthlySavingsTarget || Math.max(previousSummary.saved, 1), ASSUMPTIONS.REAL_ANNUAL_RETURN, context.age ?? undefined)
  const fireDeltaLabel = formatRelativeDelta(parseFireDateToMonthIndex(currentFire.fireDate) - parseFireDateToMonthIndex(previousFire.fireDate), true)
  const topCategory = currentSummary.topCategories[0]
  const insight = await generateInsight('weekly', {
    period_label: window.periodLabel,
    saved: currentSummary.saved,
    income: currentSummary.income,
    spending: currentSummary.spending,
    top_category: topCategory?.label ?? 'Spending',
  })

  return {
    kind: 'weekly',
    status: 'ready',
    title: 'Weekly Report',
    period_start: window.periodStart,
    period_end: window.periodEnd,
    period_label: window.periodLabel,
    story_payload: [
      heroStory('fire_this_week', 'FIRE THIS WEEK', 'purple', fireDeltaLabel, 'vs last week', 'gradient_fire', [
        row('FIRE date', context.officialFireDate ?? currentFire.fireDate),
        row('Last week', previousFire.fireDate),
        row('Net worth', formatCurrency(currentNW)),
      ]),
      heroStory('net_savings', 'NET SAVINGS', 'green', formatCurrency(currentSummary.saved), 'saved this week', 'success', [
        row('Income', formatCurrency(currentSummary.income)),
        row('Spending', formatCurrency(currentSummary.spending)),
        row('Savings rate', formatPercent(currentSummary.savingsRate)),
      ]),
      heroStory('spending_outlier', 'SPENDING OUTLIER', 'amber', formatCurrency(topCategory?.amount ?? currentSummary.spending), topCategory?.label ?? 'Top category', 'warning', [
        row('Total spend', formatCurrency(currentSummary.spending)),
        row('Transactions', `${currentSummary.transactionCount}`),
        row('2nd highest', secondCategorySummary(currentSummary.topCategories)),
      ], 'cardFigurePrimary'),
      insightStory(insight),
    ],
    metrics_payload: {
      income: toMetric(currentSummary.income),
      spending: toMetric(currentSummary.spending),
      saved: toMetric(currentSummary.saved),
    },
    insight_text: insight,
    insight_provider: INSIGHT_PROVIDER,
    generated_at: new Date().toISOString(),
  }
}

async function buildMonthlyReport(supabase: any, userId: string, context: UserContext, window: ReportWindow): Promise<ReportSnapshotDraft> {
  const transactions = await fetchTransactions(supabase, userId, window.periodStart, window.periodEnd)
  if (transactions.length < 8) {
    return pendingDraft('monthly', 'Monthly Report', window, 'Waiting for more monthly transaction data.')
  }

  const currentSummary = summarizeTransactions(transactions)
  const comparison = derivePreviousMonthWindow(window)
  const previousNW = await getNetWorthAtOrNear(supabase, userId, comparison.periodEnd, context.currentNetWorth)
  const currentNW = await getNetWorthAtOrNear(supabase, userId, window.periodEnd, context.currentNetWorth)
  const currentFire = computeFireDate(currentNW, context.fireNumber, context.monthlySavingsTarget || Math.max(currentSummary.saved, 1), ASSUMPTIONS.REAL_ANNUAL_RETURN, context.age ?? undefined)
  const previousFire = computeFireDate(previousNW, context.fireNumber, context.monthlySavingsTarget || Math.max(currentSummary.saved, 1), ASSUMPTIONS.REAL_ANNUAL_RETURN, context.age ?? undefined)
  const deltaLabel = formatRelativeDelta(parseFireDateToMonthIndex(currentFire.fireDate) - parseFireDateToMonthIndex(previousFire.fireDate), false)
  const savingsTrend = await fetchMonthlySavingsHistory(supabase, userId, 12, window.periodEnd)
  const average3MonthRate = average(savingsTrend.slice(0, 3).map((m) => m.rate))
  const bestMonth = [...savingsTrend].sort((a, b) => b.saved - a.saved)[0]
  const topCategory = currentSummary.topCategories[0]
  const previousTopAvg = await averageCategorySpend(supabase, userId, topCategory?.key ?? '', window.periodStart, 3)
  const outlierMultiple = previousTopAvg > 0 ? (topCategory?.amount ?? 0) / previousTopAvg : 0
  const salaryIncome = currentSummary.incomeBuckets.salary
  const sideIncome = Math.max(0, currentSummary.income - salaryIncome)
  const avg3MonthIncome = average(savingsTrend.slice(0, 3).map((m) => m.income))
  const insight = await generateInsight('monthly', {
    fire_delta: deltaLabel,
    savings_rate: formatPercent(currentSummary.savingsRate),
    saved: formatCurrency(currentSummary.saved),
    top_category: topCategory?.label ?? 'Spending',
    top_category_amount: formatCurrency(topCategory?.amount ?? 0),
    side_income: formatCurrency(sideIncome),
  })

  return {
    kind: 'monthly',
    status: 'ready',
    title: 'Monthly Report',
    period_start: window.periodStart,
    period_end: window.periodEnd,
    period_label: window.periodLabel,
    story_payload: [
      heroStory('fire_date', 'FIRE DATE', 'purple', deltaLabel, 'vs last month', 'gradient_fire', [
        row('FIRE date', context.officialFireDate ?? currentFire.fireDate),
        row('Prior month', previousFire.fireDate),
        row('Started', formatCurrency(currentNW)),
      ]),
      heroStory('savings_rate', 'SAVINGS RATE', 'green', formatPercent(currentSummary.savingsRate), `${formatCurrency(currentSummary.saved)} saved this month`, 'success', [
        row('3-month avg', formatPercent(average3MonthRate)),
        row('Best month', bestMonth ? `${bestMonth.label} · ${formatPercent(bestMonth.rate)}` : '—'),
        row('Target', context.monthlySavingsTarget > 0 ? `${formatCurrency(context.monthlySavingsTarget)}/mo` : '—'),
      ]),
      heroStory('spending', 'SPENDING', 'amber', formatCurrency(currentSummary.spending), 'Top 3 categories this month', 'primary', [
        row(topCategory?.label ?? 'Top category', formatCurrency(topCategory?.amount ?? 0), outlierMultiple > 1 ? `↑ ${outlierMultiple.toFixed(1)}× avg` : nil, outlierMultiple > 1 ? 'warning' : undefined),
        row(currentSummary.topCategories[1]?.label ?? '2nd category', formatCurrency(currentSummary.topCategories[1]?.amount ?? 0)),
        row(currentSummary.topCategories[2]?.label ?? '3rd category', formatCurrency(currentSummary.topCategories[2]?.amount ?? 0)),
      ], 'cardFigurePrimary'),
      {
        id: 'income',
        layout: 'hero',
        label: 'INCOME',
        background: 'blue',
        hero_text: formatCurrency(currentSummary.income),
        hero_subtext: 'earned this month',
        hero_style: 'primary',
        hero_font: 'storyHero',
        badge_text: sideIncome > 0 ? `Extra income ${formatCurrency(sideIncome)}` : null,
        rows: [
          row('Salary', formatCurrency(salaryIncome)),
          row('Side income', formatCurrency(sideIncome)),
          row('3-month avg', formatCurrency(avg3MonthIncome)),
        ],
        grid_items: [],
      },
      insightStory(insight),
    ],
    metrics_payload: {
      savings_rate: toMetric(currentSummary.savingsRate),
      saved: toMetric(currentSummary.saved),
      spending: toMetric(currentSummary.spending),
      income: toMetric(currentSummary.income),
    },
    insight_text: insight,
    insight_provider: INSIGHT_PROVIDER,
    generated_at: new Date().toISOString(),
  }
}

async function buildAnnualReport(supabase: any, userId: string, context: UserContext, window: ReportWindow): Promise<ReportSnapshotDraft> {
  const transactions = await fetchTransactions(supabase, userId, window.periodStart, window.periodEnd)
  if (transactions.length < 20) {
    return pendingDraft('annual', 'Annual Wrapped', window, 'Waiting for more annual transaction data.')
  }

  const summary = summarizeTransactions(transactions)
  const previousYear = `${Number(window.periodStart.slice(0, 4)) - 1}-12-31`
  const currentNW = await getNetWorthAtOrNear(supabase, userId, window.periodEnd, context.currentNetWorth)
  const previousNW = await getNetWorthAtOrNear(supabase, userId, previousYear, currentNW)
  const fireCurrent = computeFireDate(currentNW, context.fireNumber, context.monthlySavingsTarget || Math.max(summary.saved / 12, 1), ASSUMPTIONS.REAL_ANNUAL_RETURN, context.age ?? undefined)
  const firePrevious = computeFireDate(previousNW, context.fireNumber, context.monthlySavingsTarget || Math.max(summary.saved / 12, 1), ASSUMPTIONS.REAL_ANNUAL_RETURN, context.age ?? undefined)
  const deltaLabel = formatRelativeDelta(parseFireDateToMonthIndex(fireCurrent.fireDate) - parseFireDateToMonthIndex(firePrevious.fireDate), false)
  const monthlyHistory = await fetchMonthlySavingsHistory(supabase, userId, 12, window.periodEnd)
  const bestMonth = [...monthlyHistory].sort((a, b) => b.saved - a.saved)[0]
  const avgRate = average(monthlyHistory.map((m) => m.rate))
  const investmentReturn = Math.max(0, currentNW - previousNW - summary.saved)
  const topCategory = summary.topCategories[0]
  const previousCategoryTotal = await categorySpendForRange(supabase, userId, topCategory?.key ?? '', `${Number(window.periodStart.slice(0, 4)) - 1}-01-01`, previousYear)
  const insight = await generateInsight('annual', {
    fire_delta: deltaLabel,
    avg_savings_rate: formatPercent(avgRate),
    total_saved: formatCurrency(summary.saved),
    top_category: topCategory?.label ?? 'Spending',
    investment_return: formatCurrency(investmentReturn),
  })

  return {
    kind: 'annual',
    status: 'ready',
    title: 'Annual Wrapped',
    period_start: window.periodStart,
    period_end: window.periodEnd,
    period_label: window.periodLabel,
    story_payload: [
      heroStory('year_in_fire', `YOUR ${window.periodLabel} IN FIRE`, 'purple', deltaLabel, 'FIRE date moved closer this year', 'gradient_fire', [
        row('FIRE date now', context.officialFireDate ?? fireCurrent.fireDate),
        row('Prior year', firePrevious.fireDate),
        row('Net worth growth', formatCurrency(currentNW - previousNW)),
      ]),
      {
        id: 'year_in_numbers',
        layout: 'grid',
        label: 'YEAR IN NUMBERS',
        background: 'dark',
        hero_text: null,
        hero_subtext: null,
        hero_style: null,
        hero_font: null,
        badge_text: null,
        rows: [],
        grid_items: [
          grid('Avg savings rate', formatPercent(avgRate)),
          grid('Total saved', formatCurrency(summary.saved)),
          grid('Best month', bestMonth ? `${bestMonth.label}` : '—'),
          grid('Investment return', formatCurrency(investmentReturn)),
        ],
      },
      heroStory('biggest_outlier', 'BIGGEST OUTLIER', 'amber', formatCurrency(topCategory?.amount ?? 0), topCategory?.label ?? 'Top category', 'warning', [
        row('YoY comparison', previousCategoryTotal > 0 ? `${(((topCategory?.amount ?? 0) / previousCategoryTotal) - 1) * 100 >= 0 ? '↑' : '↓'} ${Math.abs((((topCategory?.amount ?? 0) / previousCategoryTotal) - 1) * 100).toFixed(0)}%` : '—'),
        row('Monthly avg', formatCurrency((topCategory?.amount ?? 0) / 12)),
        row('Savings impact', formatCurrency(((topCategory?.amount ?? 0) / 12) * 0.2)),
      ], 'cardFigurePrimary'),
      insightStory(insight, 'year_in_review', 'YEAR IN REVIEW'),
    ],
    metrics_payload: {
      avg_savings_rate: toMetric(avgRate),
      total_saved: toMetric(summary.saved),
      investment_return: toMetric(investmentReturn),
    },
    insight_text: insight,
    insight_provider: INSIGHT_PROVIDER,
    generated_at: new Date().toISOString(),
  }
}

async function buildIssueZeroReport(supabase: any, userId: string, context: UserContext, window: ReportWindow): Promise<ReportSnapshotDraft> {
  const transactions = await fetchTransactions(supabase, userId, window.periodStart, window.periodEnd)
  if (transactions.length < 10) {
    return pendingDraft('issue_zero', 'Issue Zero', window, 'Waiting for your first batch of synced transactions.')
  }

  const summary = summarizeTransactions(transactions)
  const monthlyHistory = await fetchMonthlySavingsHistory(supabase, userId, 6, window.periodEnd)
  const monthsAnalyzed = Math.max(monthlyHistory.length, 1)
  const avgRate = average(monthlyHistory.map((m) => m.rate))
  const topCategory = summary.topCategories[0]

  return {
    kind: 'issue_zero',
    status: 'ready',
    title: 'Issue Zero',
    period_start: window.periodStart,
    period_end: window.periodEnd,
    period_label: window.periodLabel,
    story_payload: [
      {
        id: 'headline',
        layout: 'headline',
        label: null,
        background: 'purple',
        hero_text: "Here's what\nwe found.",
        hero_subtext: `Based on ${monthsAnalyzed} months of transactions`,
        hero_style: 'primary',
        hero_font: 'h1',
        badge_text: null,
        rows: [],
        grid_items: [],
      },
      heroStory('avg_savings_rate', 'SAVINGS RATE', 'green', formatPercent(avgRate), `across ${monthsAnalyzed} months of data`, 'success', []),
      heroStory('top_category', 'TOP CATEGORY', 'amber', formatCurrency(topCategory?.amount ?? 0), `${formatCurrency((topCategory?.amount ?? 0) / monthsAnalyzed)}/mo on ${topCategory?.label ?? 'spending'}`, 'warning', []),
      {
        id: 'whats_next',
        layout: 'cta',
        label: "WHAT'S NEXT",
        background: 'dark',
        hero_text: 'Starting next month',
        hero_subtext: 'You will get a weekly recap, monthly story, and annual wrap when they are ready.',
        hero_style: 'primary',
        hero_font: 'h2',
        badge_text: null,
        rows: [
          row('Weekly', 'Short progress snapshots'),
          row('Monthly', 'FIRE progress stories'),
          row('Annual', 'One full-year review'),
        ],
        grid_items: [],
        cta_label: 'Got it',
      },
    ],
    metrics_payload: {
      avg_savings_rate: toMetric(avgRate),
      top_category_amount: toMetric(topCategory?.amount ?? 0),
      months_analyzed: `${monthsAnalyzed}`,
    },
    insight_text: null,
    insight_provider: null,
    generated_at: new Date().toISOString(),
  }
}

async function fetchUserContext(supabase: any, userId: string): Promise<UserContext> {
  const [profileResult, goalResult, planResult] = await Promise.all([
    supabase
      .from('user_profiles')
      .select('age, plaid_net_worth, current_net_worth')
      .eq('user_id', userId)
      .maybeSingle(),
    supabase
      .from('fire_goals')
      .select('fire_number, retirement_spending_monthly, withdrawal_rate_assumption, return_assumption')
      .eq('user_id', userId)
      .eq('is_active', true)
      .maybeSingle(),
    supabase
      .from('active_plans')
      .select('savings_target_monthly, official_fire_date, official_fire_age')
      .eq('user_id', userId)
      .eq('is_active', true)
      .maybeSingle(),
  ])

  const goal = goalResult.data
  const profile = profileResult.data
  const plan = planResult.data

  const currentNetWorth = profile?.plaid_net_worth ?? profile?.current_net_worth ?? 0
  const fireNumber = goal?.fire_number && goal.fire_number > 0
    ? Number(goal.fire_number)
    : computeFireNumber(
        Number(goal?.retirement_spending_monthly ?? 4000),
        Number(goal?.withdrawal_rate_assumption ?? ASSUMPTIONS.WITHDRAWAL_RATE)
      )

  return {
    age: profile?.age ?? null,
    currentNetWorth,
    fireNumber,
    monthlySavingsTarget: Number(plan?.savings_target_monthly ?? 0),
    officialFireDate: plan?.official_fire_date ?? null,
    officialFireAge: plan?.official_fire_age ?? null,
  }
}

async function fetchTransactions(supabase: any, userId: string, startDate: string, endDate: string): Promise<TxRow[]> {
  const { data } = await supabase
    .from('transactions')
    .select('amount, date, flamora_category, flamora_subcategory, merchant_name, name')
    .eq('user_id', userId)
    .eq('pending', false)
    .gte('date', startDate)
    .lte('date', endDate)

  return (data ?? []) as TxRow[]
}

async function fetchMonthlySavingsHistory(supabase: any, userId: string, monthCount: number, endDate: string) {
  const end = new Date(`${endDate}T00:00:00Z`)
  const monthWindows = Array.from({ length: monthCount }, (_, index) => {
    const endOfMonth = new Date(Date.UTC(end.getUTCFullYear(), end.getUTCMonth() - index + 1, 0))
    const startOfMonth = new Date(Date.UTC(endOfMonth.getUTCFullYear(), endOfMonth.getUTCMonth(), 1))
    return {
      label: formatMonthShort(endOfMonth),
      start: toISODate(startOfMonth),
      end: toISODate(endOfMonth),
    }
  })

  const history: Array<{ label: string; income: number; spending: number; saved: number; rate: number }> = []

  for (const month of monthWindows) {
    const summary = summarizeTransactions(await fetchTransactions(supabase, userId, month.start, month.end))
    history.push({
      label: month.label,
      income: summary.income,
      spending: summary.spending,
      saved: summary.saved,
      rate: summary.savingsRate,
    })
  }

  return history
}

async function getNetWorthAtOrNear(supabase: any, userId: string, date: string, fallback: number) {
  const { data } = await supabase
    .from('net_worth_history')
    .select('total_net_worth')
    .eq('user_id', userId)
    .lte('date', date)
    .order('date', { ascending: false })
    .limit(1)
    .maybeSingle()

  return Number(data?.total_net_worth ?? fallback)
}

async function averageCategorySpend(supabase: any, userId: string, categoryKey: string, beforeDate: string, monthCount: number) {
  if (!categoryKey) return 0
  const anchor = new Date(`${beforeDate}T00:00:00Z`)
  let total = 0
  let months = 0
  for (let index = 1; index <= monthCount; index++) {
    const end = new Date(Date.UTC(anchor.getUTCFullYear(), anchor.getUTCMonth() - index + 1, 0))
    const start = new Date(Date.UTC(end.getUTCFullYear(), end.getUTCMonth(), 1))
    total += await categorySpendForRange(supabase, userId, categoryKey, toISODate(start), toISODate(end))
    months += 1
  }
  return months > 0 ? total / months : 0
}

async function categorySpendForRange(supabase: any, userId: string, categoryKey: string, startDate: string, endDate: string) {
  if (!categoryKey) return 0
  const { data } = await supabase
    .from('transactions')
    .select('amount')
    .eq('user_id', userId)
    .eq('pending', false)
    .eq('flamora_subcategory', categoryKey)
    .in('flamora_category', ['needs', 'wants'])
    .gte('date', startDate)
    .lte('date', endDate)

  return (data ?? []).reduce((sum: number, row: any) => sum + Math.max(Number(row.amount ?? 0), 0), 0)
}

function summarizeTransactions(transactions: TxRow[]) {
  let income = 0
  let spending = 0
  let salary = 0
  const topMap = new Map<string, number>()

  for (const tx of transactions) {
    const amount = Number(tx.amount ?? 0)
    const category = tx.flamora_category ?? 'uncategorized'
    const subcategory = tx.flamora_subcategory ?? category

    if (category === 'income') {
      const value = Math.abs(amount)
      income += value
      if (['salary', 'wages', 'payroll'].includes(subcategory)) {
        salary += value
      }
      continue
    }

    if ((category === 'needs' || category === 'wants') && amount > 0) {
      spending += amount
      topMap.set(subcategory, (topMap.get(subcategory) ?? 0) + amount)
    }
  }

  const saved = income - spending
  const savingsRate = income > 0 ? (saved / income) * 100 : 0
  const topCategories = [...topMap.entries()]
    .map(([key, amount]) => ({
      key,
      label: titleize(key),
      amount,
    }))
    .sort((a, b) => b.amount - a.amount)

  return {
    income,
    spending,
    saved,
    savingsRate,
    transactionCount: transactions.length,
    topCategories,
    incomeBuckets: {
      salary,
    },
  }
}

async function generateInsight(kind: ReportKind, metrics: Record<string, string | number>) {
  const apiKey = Deno.env.get('GROQ_API_KEY')
  if (!apiKey) {
    return fallbackInsight(kind, metrics)
  }

  try {
    const system = 'You are writing a short, sharp financial story insight for Flamora. Return one concise paragraph in plain text, 2 sentences max.'
    const prompt = `Kind: ${kind}\nMetrics: ${JSON.stringify(metrics)}\nWrite an encouraging but specific insight with no bullet points.`

    const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: 'llama-3.3-70b-versatile',
        temperature: 0.4,
        max_tokens: 120,
        messages: [
          { role: 'system', content: system },
          { role: 'user', content: prompt },
        ],
      }),
    })

    if (!response.ok) {
      return fallbackInsight(kind, metrics)
    }

    const json = await response.json()
    const text = json?.choices?.[0]?.message?.content?.trim()
    return text || fallbackInsight(kind, metrics)
  } catch {
    return fallbackInsight(kind, metrics)
  }
}

function fallbackInsight(kind: ReportKind, metrics: Record<string, string | number>) {
  switch (kind) {
    case 'weekly':
      return `This week worked because your spending stayed below income, which let the extra cash do real work. If you repeat this mix next week, your FIRE timeline keeps tightening.`
    case 'monthly':
      return `Your month was defined more by spending discipline than by one lucky paycheck. That is exactly the kind of progress that compounds into a meaningfully earlier FIRE date.`
    case 'annual':
      return `This year moved the big pieces, not just the small ones. The combination of steady saving and fewer spending spikes made your path more durable going into next year.`
    case 'issue_zero':
      return `Your first snapshot already shows where momentum exists and where it leaks away. The goal now is not perfection, but turning these patterns into a repeatable monthly story.`
  }
}

function pendingDraft(kind: ReportKind, title: string, window: ReportWindow, reason: string): ReportSnapshotDraft {
  return {
    kind,
    status: 'pending',
    title,
    period_start: window.periodStart,
    period_end: window.periodEnd,
    period_label: window.periodLabel,
    story_payload: [],
    metrics_payload: { reason },
    insight_text: null,
    insight_provider: null,
    generated_at: null,
  }
}

function derivePreviousWindow(window: ReportWindow): ReportWindow {
  const start = new Date(`${window.periodStart}T00:00:00Z`)
  const end = new Date(`${window.periodEnd}T00:00:00Z`)
  const daySpan = Math.round((end.getTime() - start.getTime()) / 86400000)
  const previousEnd = addDays(start, -1)
  const previousStart = addDays(previousEnd, -daySpan)
  return {
    kind: window.kind,
    periodStart: toISODate(previousStart),
    periodEnd: toISODate(previousEnd),
    periodLabel: `${formatShortDate(previousStart)} – ${formatShortDate(previousEnd)}`,
  }
}

function derivePreviousMonthWindow(window: ReportWindow): ReportWindow {
  const start = new Date(`${window.periodStart}T00:00:00Z`)
  const previousEnd = addDays(start, -1)
  const previousStart = new Date(Date.UTC(previousEnd.getUTCFullYear(), previousEnd.getUTCMonth(), 1))
  return {
    kind: window.kind,
    periodStart: toISODate(previousStart),
    periodEnd: toISODate(previousEnd),
    periodLabel: formatMonthYear(previousEnd),
  }
}

function heroStory(
  id: string,
  label: string,
  background: StoryBackground,
  heroText: string,
  heroSubtext: string,
  heroStyle: HeroStyle,
  rows: StoryMetricRow[],
  heroFont: HeroFont = 'storyHero'
): StoryPayload {
  return {
    id,
    layout: 'hero',
    label,
    background,
    hero_text: heroText,
    hero_subtext: heroSubtext,
    hero_style: heroStyle,
    hero_font: heroFont,
    rows,
    grid_items: [],
  }
}

function insightStory(text: string, id = 'insight', label = 'AI INSIGHT'): StoryPayload {
  return {
    id,
    layout: 'insight',
    label,
    background: 'dark',
    rows: [],
    grid_items: [],
    insight_text: text,
    insight_source: 'Powered by Llama 3.3 via Groq',
  }
}

function row(label: string, value: string, note?: string | null, valueStyle?: HeroStyle): StoryMetricRow {
  return {
    id: crypto.randomUUID(),
    label,
    value,
    note: note ?? null,
    value_style: valueStyle ?? null,
  }
}

function grid(label: string, value: string): StoryGridItem {
  return {
    id: crypto.randomUUID(),
    label,
    value,
  }
}

function secondCategorySummary(categories: Array<{ label: string; amount: number }>) {
  const second = categories[1]
  if (!second) return '—'
  return `${second.label} · ${formatCurrency(second.amount)}`
}

function parseFireDateToMonthIndex(fireDate: string) {
  if (!fireDate || fireDate === 'Unknown') return 0
  const [monthName, yearText] = fireDate.split(' ')
  const year = Number(yearText)
  const month = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'].indexOf(monthName)
  if (year <= 0 || month < 0) return 0
  return year * 12 + month
}

function formatRelativeDelta(deltaMonths: number, preferWeeks: boolean) {
  if (deltaMonths === 0) return preferWeeks ? '0 wk' : '0 mo'
  const direction = deltaMonths < 0 ? '' : '+'
  if (preferWeeks) {
    return `${direction}${Math.max(1, Math.abs(deltaMonths) * 4)} wk`
  }
  return `${direction}${Math.abs(deltaMonths)} mo`
}

function formatCurrency(value: number) {
  const rounded = Math.round(value)
  const sign = rounded < 0 ? '-' : ''
  const abs = Math.abs(rounded)
  return `${sign}$${abs.toLocaleString()}`
}

function formatPercent(value: number) {
  return `${Math.round(value)}%`
}

function titleize(value: string) {
  return value
    .replaceAll('_', ' ')
    .split(' ')
    .filter(Boolean)
    .map((chunk) => chunk[0].toUpperCase() + chunk.slice(1))
    .join(' ')
}

function toMetric(value: number) {
  return Number.isFinite(value) ? value.toFixed(2) : '0'
}

function average(values: number[]) {
  if (values.length === 0) return 0
  return values.reduce((sum, value) => sum + value, 0) / values.length
}

function addDays(date: Date, days: number) {
  const copy = new Date(date.getTime())
  copy.setUTCDate(copy.getUTCDate() + days)
  return copy
}

function toISODate(date: Date) {
  return date.toISOString().slice(0, 10)
}

function formatMonthYear(date: Date) {
  return date.toLocaleString('en-US', { month: 'long', year: 'numeric', timeZone: 'UTC' })
}

function formatMonthShort(date: Date) {
  return date.toLocaleString('en-US', { month: 'short', timeZone: 'UTC' })
}

function formatShortDate(date: Date) {
  return `${date.toLocaleString('en-US', { month: 'short', timeZone: 'UTC' })} ${date.getUTCDate()}`
}
