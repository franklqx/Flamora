// supabase/functions/_shared/plan-generator.ts
//
// V3 Budget Module — pure plan generation.
// Implements `computeBudgetPlans` + `dedupePlans` + `COPY_TEMPLATES`
// per `~/.claude/plans/budget-plan-budget-plan-gentle-blossom.md` § 核心算法.
//
// Returns 1-3 plans (primary always present; comfortable / accelerated may be
// folded by dedupe). The primary plan's `feasibility` field truthfully reports
// whether the user's target is reachable — never disguised as a hit.
//
// AI is NOT involved at any layer. All copy is deterministic.

import { GUARDRAILS } from './budget-guardrails.ts'
import { monthsToFIRE, solveRequiredSave } from './fire-math.ts'

// ============================================================
// Types
// ============================================================

export type Feasibility =
  | 'exact'
  | 'closest_near'
  | 'closest_far'
  | 'already_fire'
  | 'lifestyle'
  | 'acceleration'

export type PlanLabel =
  | 'target-aligned'
  | 'closest_near'
  | 'closest_far'
  | 'already_fire'
  | 'comfortable'
  | 'accelerated'
  | 'custom'

export type Anchor = 'target' | 'lifestyle' | 'acceleration'

export type LimitReason = 'essentials_floor' | 'savings_rate_cap'

export type InfeasibilityReason =
  | 'deficit'
  | 'target_too_soon'
  | 'deficit_and_target_too_soon'
  | 'cap_exceeded'

export interface PlanInput {
  /** User-chosen target retirement age (Step 4). */
  targetAge: number
  /** From profile. */
  currentAge: number
  /** Snapshot total assets minus debts. */
  netWorth: number
  /** From spending-stats. */
  avgIncome: number
  /** From spending-stats (median). */
  avgSpend: number
  /** From spending-stats (rent + util + transp + medical + groceries × 0.6). */
  essentialFloor: number
  /** Sum of canonical wants categories from spending-stats. */
  avgWants: number
  /** Step 4 retirement spending input (defaults to today's spend). */
  retirementSpending: number
  /** What the user is saving today (income - spend). Used for "X more than today" copy. */
  currentMonthlySave?: number
  /** SWR for FIRE number derivation; defaults to 4%. */
  withdrawalRate?: number
  /** Real return for FIRE math; defaults to GUARDRAILS.realReturn. */
  realReturn?: number
}

export interface PlanOutput {
  feasibility: Feasibility
  anchor: Anchor
  label: PlanLabel
  reason: InfeasibilityReason | null
  limitReason: LimitReason | null

  // Numbers (all dollars are monthly unless suffixed)
  monthlySave: number
  monthlySpendCeiling: number
  savingsRate: number          // 0..1 ratio
  fireNumber: number
  fireAgeMonths: number        // months from now to reach FIRE
  fireAge: number              // currentAge + ceil(months/12), or 0 for already_fire
  fireAgeYears: number         // alias kept for V4 dedupe ordering tests
  gapMonths: number            // fireAgeMonths - targetMonths (positive = late)
  gapYears: number             // ceil(gapMonths / 12), 0 if not late

  // Deterministic copy
  headline: string
  sub: string
  badge: string | null
  cta: { label: string; action: string } | null
}

export interface CustomSliderRange {
  isAvailable: boolean
  minMonthlySave: number | null
  maxMonthlySave: number | null
}

// ============================================================
// Internal helpers (formatting + ceiling derivation)
// ============================================================

function money(value: number): string {
  const sign = value < 0 ? '-' : ''
  return `${sign}$${Math.round(Math.abs(value)).toLocaleString('en-US')}`
}

function pct(ratio: number): string {
  return `${Math.round(ratio * 100)}%`
}

function ceilingMonthsToYears(months: number): number {
  if (!Number.isFinite(months)) return 99
  return Math.ceil(months / 12)
}

/**
 * Derive monthly spend ceiling from save amount.
 * Plan §术语: ceiling = avgIncome × (1 − savingsRate); already_fire is special.
 */
function deriveSpendCeiling(args: {
  feasibility: Feasibility
  monthlySave: number
  avgIncome: number
  retirementSpending: number
}): number {
  if (args.feasibility === 'already_fire') return args.retirementSpending
  return Math.max(0, args.avgIncome - args.monthlySave)
}

// ============================================================
// Plan builder (assembles numbers + canonical copy)
// ============================================================

interface BuildPlanArgs {
  feasibility: Feasibility
  anchor: Anchor
  reason?: InfeasibilityReason | null
  limitReason?: LimitReason | null
  save: number
  fireAgeMonthsOverride?: number
}

function buildPlan(input: PlanInput, fireNumber: number, args: BuildPlanArgs): PlanOutput {
  const realReturn = input.realReturn ?? GUARDRAILS.realReturn
  const targetMonths = (input.targetAge - input.currentAge) * 12

  const fireAgeMonths = args.fireAgeMonthsOverride ?? (
    args.feasibility === 'already_fire'
      ? 0
      : monthsToFIRE(input.netWorth, args.save, fireNumber, realReturn)
  )

  const fireAgeYearsRaw = ceilingMonthsToYears(fireAgeMonths)
  const fireAge = args.feasibility === 'already_fire' ? input.currentAge : input.currentAge + fireAgeYearsRaw

  const gapMonths = Math.max(0, fireAgeMonths - targetMonths)
  const gapYears = ceilingMonthsToYears(gapMonths)

  const savingsRate = input.avgIncome > 0 ? args.save / input.avgIncome : 0
  const spendCeiling = deriveSpendCeiling({
    feasibility: args.feasibility,
    monthlySave: args.save,
    avgIncome: input.avgIncome,
    retirementSpending: input.retirementSpending,
  })

  const label = labelFor(args.feasibility, args.anchor)
  const copy = makeCopy({
    feasibility: args.feasibility,
    reason: args.reason ?? null,
    limitReason: args.limitReason ?? null,
    save: args.save,
    currentSave: input.currentMonthlySave ?? Math.max(0, input.avgIncome - input.avgSpend),
    targetAge: input.targetAge,
    fireAge,
    gapYears,
    spendCut: Math.max(0, input.avgSpend - spendCeiling),
    wantsLeft: Math.max(0, input.avgWants * GUARDRAILS.aggressiveWantsKeep),
    netWorth: input.netWorth,
    fireNumber,
    avgIncome: input.avgIncome,
    essentialFloor: input.essentialFloor,
    hitsTarget: fireAgeMonths <= targetMonths,
    beatsTarget: fireAgeMonths < targetMonths,
    beatYears: Math.max(0, ceilingMonthsToYears(targetMonths - fireAgeMonths)),
  })

  return {
    feasibility: args.feasibility,
    anchor: args.anchor,
    label,
    reason: args.reason ?? null,
    limitReason: args.limitReason ?? null,
    monthlySave: args.save,
    monthlySpendCeiling: spendCeiling,
    savingsRate,
    fireNumber,
    fireAgeMonths,
    fireAge,
    fireAgeYears: fireAgeYearsRaw,
    gapMonths,
    gapYears,
    headline: copy.headline,
    sub: copy.sub,
    badge: copy.badge,
    cta: copy.cta,
  }
}

// ============================================================
// COPY_TEMPLATES (deterministic, mirrors plan §Plan 文案模板)
// ============================================================

interface CopyArgs {
  feasibility: Feasibility
  reason: InfeasibilityReason | null
  limitReason: LimitReason | null
  save: number
  currentSave: number
  targetAge: number
  fireAge: number
  gapYears: number
  spendCut: number
  wantsLeft: number
  netWorth: number
  fireNumber: number
  avgIncome: number
  essentialFloor: number
  hitsTarget: boolean
  beatsTarget: boolean
  beatYears: number
}

interface CopyResult {
  headline: string
  sub: string
  badge: string | null
  cta: { label: string; action: string } | null
}

function makeCopy(p: CopyArgs): CopyResult {
  switch (p.feasibility) {
    case 'exact':
      return {
        headline: `To retire at ${p.targetAge}, save ${money(p.save)}/mo`,
        sub: p.save > p.currentSave
          ? `That's ${money(p.save - p.currentSave)} more than you save today`
          : `✓ You already save enough`,
        badge: '✓ Hits your target',
        cta: null,
      }

    case 'closest_near': {
      const reasonClause = p.limitReason === 'essentials_floor'
        ? `would require cutting into essential expenses (rent, utilities, medical)`
        : `would require saving over ${pct(GUARDRAILS.maxSavingsRateCap)} of income, which we cap as a safety limit`
      return {
        headline: `Closest reasonable plan: save ${money(p.save)}/mo`,
        sub: `Hitting ${p.targetAge} exactly ${reasonClause}. This plan saves ${money(p.save)}/mo and hits age ${p.fireAge} (+${p.gapYears}y vs target).`,
        badge: `+${p.gapYears}y vs target`,
        cta: null,
      }
    }

    case 'closest_far': {
      let headline: string
      let sub: string
      if (p.reason === 'deficit' || p.reason === 'deficit_and_target_too_soon') {
        headline = `Your essential expenses exceed your income`
        sub = `Spending ${money(p.essentialFloor)}/mo on essentials but earning only ${money(p.avgIncome)}/mo. We can't recommend a savings plan until income covers essentials.`
      } else if (p.reason === 'target_too_soon') {
        headline = `Target age ${p.targetAge} is too soon`
        sub = p.save > 0
          ? `The earliest you could realistically reach FIRE is age ${p.fireAge}, by saving ${money(p.save)}/mo.`
          : `Pick a target at least 1 year away to get a plan.`
      } else {
        headline = `Your target isn't reachable within reasonable limits`
        const reasonClause = p.limitReason === 'essentials_floor'
          ? `even cutting all discretionary spending`
          : `even at our ${pct(GUARDRAILS.maxSavingsRateCap)} savings cap`
        sub = `${reasonClause}, the earliest you reach FIRE is age ${p.fireAge} (+${p.gapYears}y vs ${p.targetAge}). Consider adjusting your target.`
      }
      return {
        headline,
        sub,
        badge: null,
        cta: { label: 'Adjust target', action: 'openStep4Sheet' },
      }
    }

    case 'lifestyle':
      return {
        headline: `Keep today's lifestyle: save ${money(p.save)}/mo`,
        sub: `Trim ${money(p.spendCut)}/mo off current spending · FIRE at ${p.fireAge}`,
        badge: p.beatsTarget
          ? `-${p.beatYears}y before target`
          : p.hitsTarget
            ? '✓ Hits target'
            : `+${p.gapYears}y vs target`,
        cta: null,
      }

    case 'acceleration':
      return {
        headline: `Push harder: save ${money(p.save)}/mo`,
        sub: `Cut wants to ${money(p.wantsLeft)}/mo · FIRE at ${p.fireAge}`,
        badge: p.beatsTarget ? `-${p.beatYears}y before target ✨` : `+${p.gapYears}y vs target`,
        cta: null,
      }

    case 'already_fire':
      return {
        headline: `You've already hit FIRE 🎉`,
        sub: `Net worth ${money(p.netWorth)} ≥ FIRE number ${money(p.fireNumber)}. You can stop saving and start tracking sustainable spending.`,
        badge: '✓ Already free',
        cta: { label: 'Start tracking', action: 'goConfirm' },
      }
  }
}

// ============================================================
// feasibility / anchor → committed_plan_label mapping
// ============================================================

function labelFor(feasibility: Feasibility, anchor: Anchor): PlanLabel {
  if (feasibility === 'already_fire') return 'already_fire'
  if (feasibility === 'closest_near') return 'closest_near'
  if (feasibility === 'closest_far') return 'closest_far'
  if (feasibility === 'exact') return 'target-aligned'
  if (anchor === 'lifestyle') return 'comfortable'
  if (anchor === 'acceleration') return 'accelerated'
  return 'target-aligned'
}

// ============================================================
// computeBudgetPlans
// ============================================================

export function computeBudgetPlans(input: PlanInput): PlanOutput[] {
  const withdrawalRate = input.withdrawalRate ?? 0.04
  const fireNumber = (1 / withdrawalRate) * input.retirementSpending * 12
  const targetMonths = (input.targetAge - input.currentAge) * 12
  const realReturn = input.realReturn ?? GUARDRAILS.realReturn

  // ---- Short-circuit 0: already at FIRE ----
  if (input.netWorth >= fireNumber) {
    return [buildPlan(input, fireNumber, {
      feasibility: 'already_fire',
      anchor: 'target',
      save: 0,
      fireAgeMonthsOverride: 0,
    })]
  }

  // ---- Constraints used by both short-circuits and main path ----
  const isDeficit = input.avgIncome <= input.essentialFloor
  const maxFeasibleSave = isDeficit ? 0 : Math.max(0, Math.min(
    input.avgIncome - input.essentialFloor,
    input.avgIncome * GUARDRAILS.maxSavingsRateCap,
  ))

  // ---- Short-circuit 1: target window too short (incl. targetAge ≤ currentAge) ----
  if (targetMonths < GUARDRAILS.minTargetWindowMonths) {
    if (maxFeasibleSave <= 0) {
      // Both deficit AND target too soon — truly nothing to recommend.
      return [buildPlan(input, fireNumber, {
        feasibility: 'closest_far',
        anchor: 'target',
        save: 0,
        reason: 'deficit_and_target_too_soon',
      })]
    }
    return [buildPlan(input, fireNumber, {
      feasibility: 'closest_far',
      anchor: 'target',
      save: maxFeasibleSave,
      reason: 'target_too_soon',
    })]
  }

  // ---- Plan A (primary): target-aligned ----
  let primary: PlanOutput

  if (isDeficit || maxFeasibleSave <= 0) {
    primary = buildPlan(input, fireNumber, {
      feasibility: 'closest_far',
      anchor: 'target',
      save: 0,
      reason: 'deficit',
    })
  } else {
    const requiredSave = solveRequiredSave(input.netWorth, targetMonths, fireNumber, realReturn)
    const isTargetFeasible = requiredSave <= maxFeasibleSave

    if (isTargetFeasible) {
      primary = buildPlan(input, fireNumber, {
        feasibility: 'exact',
        anchor: 'target',
        save: requiredSave,
        fireAgeMonthsOverride: targetMonths,
      })
    } else {
      const cappedByEssentials =
        (input.avgIncome - input.essentialFloor) <= (input.avgIncome * GUARDRAILS.maxSavingsRateCap)
      const limitReason: LimitReason = cappedByEssentials ? 'essentials_floor' : 'savings_rate_cap'
      const closestFireMonths = monthsToFIRE(input.netWorth, maxFeasibleSave, fireNumber, realReturn)
      const gapMonths = closestFireMonths - targetMonths
      const feasibility: Feasibility = gapMonths <= GUARDRAILS.nearTargetWindowMonths
        ? 'closest_near'
        : 'closest_far'
      primary = buildPlan(input, fireNumber, {
        feasibility,
        anchor: 'target',
        save: maxFeasibleSave,
        limitReason,
      })
    }
  }

  // ---- Deficit / no-save → primary only ----
  if (isDeficit || maxFeasibleSave <= 0) return [primary]

  // ---- Plan B (comfortable): only compress 15% of discretionary ----
  const compressible = Math.max(0, input.avgSpend - input.essentialFloor)
  const comfortableSpend = input.essentialFloor + compressible * GUARDRAILS.comfortableDiscretionaryKeep
  const comfortableSave = Math.max(0, Math.min(
    input.avgIncome - comfortableSpend,
    input.avgIncome * GUARDRAILS.maxSavingsRateCap,
  ))
  const comfortable = buildPlan(input, fireNumber, {
    feasibility: 'lifestyle',
    anchor: 'lifestyle',
    save: comfortableSave,
  })

  // ---- Plan C (accelerated): wants down to 30% ----
  const aggressiveSpend = input.essentialFloor + input.avgWants * GUARDRAILS.aggressiveWantsKeep
  const aggressiveSave = Math.max(0, Math.min(
    input.avgIncome - aggressiveSpend,
    input.avgIncome * GUARDRAILS.maxSavingsRateCap,
  ))
  const accelerated = buildPlan(input, fireNumber, {
    feasibility: 'acceleration',
    anchor: 'acceleration',
    save: aggressiveSave,
  })

  return dedupePlans([primary, comfortable, accelerated])
}

// ============================================================
// dedupePlans
// ============================================================

export function dedupePlans(plans: PlanOutput[]): PlanOutput[] {
  if (plans.length === 0) return plans
  const [primary, ...rest] = plans
  const output: PlanOutput[] = [primary]

  function meaningfulDiff(a: PlanOutput, b: PlanOutput): boolean {
    const saveDiff = Math.abs(a.monthlySave - b.monthlySave)
    const ageDiff = Math.abs(a.fireAgeYears - b.fireAgeYears)
    return saveDiff >= GUARDRAILS.meaningfulSaveDiffDollars
        && ageDiff  >= GUARDRAILS.meaningfulFireAgeDiffYears
  }

  for (const candidate of rest) {
    // 1. Must be meaningfully different from primary
    if (!meaningfulDiff(candidate, primary)) continue
    // 2. When primary is already capped (closest_*), candidates with higher save are noise
    if (primary.feasibility !== 'exact' && candidate.monthlySave > primary.monthlySave) continue
    // 3. Must also be meaningfully different from already-added candidates
    if (output.slice(1).some(existing => !meaningfulDiff(candidate, existing))) continue
    output.push(candidate)
  }

  return output
}

export function deriveCustomSliderRange(input: PlanInput, primary: PlanOutput): CustomSliderRange {
  if (primary.feasibility === 'already_fire') {
    return { isAvailable: false, minMonthlySave: null, maxMonthlySave: null }
  }

  const isDeficit = input.avgIncome <= input.essentialFloor
  const maxFeasibleSave = isDeficit ? 0 : Math.max(0, Math.min(
    input.avgIncome - input.essentialFloor,
    input.avgIncome * GUARDRAILS.maxSavingsRateCap,
  ))

  if (isDeficit || maxFeasibleSave <= 0) {
    return { isAvailable: false, minMonthlySave: null, maxMonthlySave: null }
  }

  const minMonthlySave = Math.min(input.avgIncome * GUARDRAILS.minSavingsRateFloor, maxFeasibleSave)
  const maxMonthlySave = maxFeasibleSave
  const isAvailable = (maxMonthlySave - minMonthlySave) >= GUARDRAILS.customSliderMinRangeDollars

  return {
    isAvailable,
    minMonthlySave: isAvailable ? minMonthlySave : null,
    maxMonthlySave: isAvailable ? maxMonthlySave : null,
  }
}
