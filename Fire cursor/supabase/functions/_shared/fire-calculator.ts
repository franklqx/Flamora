// supabase/functions/_shared/fire-calculator.ts

import { ASSUMPTIONS } from './fire-assumptions.ts'

export interface AdjustGoalInput {
  monthlyIncome: number
  currentAge: number
  targetRetirementAge: number
  desiredMonthlyExpenses: number
  currentNetWorth: number
  currentMonthlyExpenses: number
}

export interface PathDetail {
  retirement_age: number
  savings_rate: number
  monthly_savings: number
  feasibility: 'comfortable' | 'balanced' | 'aggressive' | 'unrealistic'
}

export interface AdjustGoalResult {
  phase: 0 | 1 | 2
  phase_sub: string             // "0a","0b","0c","0d","1","2"
  strategy: 'goal_achievable' | 'user_choice' | 'impossible'
  fire_number: number
  gap_to_fire: number
  required_monthly_contribution: number
  required_savings_rate: number
  years_to_retirement: number
  is_achievable: boolean
  current_path: PathDetail
  plan_a: PathDetail | null   // Keep target age, increase savings
  plan_b: PathDetail | null   // Keep current savings, delay retirement
  recommended: PathDetail | null
}

// Feasibility calculations use real return (purchasing-power consistent with FIRE number).
const ANNUAL_RETURN = ASSUMPTIONS.REAL_ANNUAL_RETURN
const MONTHLY_RATE = ANNUAL_RETURN / 12
const WITHDRAWAL_RATE = ASSUMPTIONS.WITHDRAWAL_RATE

export class FIRECalculator {

  /**
   * Core: compute future value given monthly contribution over N months
   */
  private futureValue(currentNW: number, monthlySavings: number, months: number): number {
    if (months <= 0) return currentNW
    const fvPV = currentNW * Math.pow(1 + MONTHLY_RATE, months)
    const fvPMT = monthlySavings * ((Math.pow(1 + MONTHLY_RATE, months) - 1) / MONTHLY_RATE)
    return fvPV + fvPMT
  }

  /**
   * Find retirement age given a fixed monthly savings amount
   * Uses iterative year-by-year compound growth (matches OnboardingData.swift)
   */
  private findRetirementAge(
    currentAge: number,
    currentNW: number,
    monthlySavings: number,
    fireNumber: number,
    maxYears: number = 80
  ): number {
    let accumulated = currentNW
    let years = 0
    while (accumulated < fireNumber && years < maxYears) {
      accumulated = accumulated * (1 + ANNUAL_RETURN) + monthlySavings * 12
      years++
    }
    return currentAge + years
  }

  /**
   * Find required monthly savings to reach fireNumber in exactly N years
   * Reverse-solves the FV equation
   */
  private requiredMonthlySavings(
    currentNW: number,
    fireNumber: number,
    years: number
  ): number {
    if (years <= 0) return Math.max(0, fireNumber - currentNW)
    const months = years * 12
    const fvPV = currentNW * Math.pow(1 + MONTHLY_RATE, months)
    const remaining = fireNumber - fvPV
    if (remaining <= 0) return 0 // Already achievable with just compounding
    const factor = (Math.pow(1 + MONTHLY_RATE, months) - 1) / MONTHLY_RATE
    return remaining / factor
  }

  private classifyFeasibility(savingsRate: number): PathDetail['feasibility'] {
    if (savingsRate <= 25) return 'comfortable'
    if (savingsRate <= 40) return 'balanced'
    if (savingsRate <= 60) return 'aggressive'
    return 'unrealistic'
  }

  adjustGoal(input: AdjustGoalInput): AdjustGoalResult {
    const {
      monthlyIncome,
      currentAge,
      targetRetirementAge,
      desiredMonthlyExpenses,
      currentNetWorth,
      currentMonthlyExpenses,
    } = input

    const yearsToRetirement = Math.max(targetRetirementAge - currentAge, 1)
    const fireNumber = desiredMonthlyExpenses * 12 * (1 / WITHDRAWAL_RATE) // 25x annual expenses
    const gapToFire = Math.max(fireNumber - currentNetWorth, 0)

    // Current path
    const currentSavings = Math.max(0, monthlyIncome - currentMonthlyExpenses)
    const currentSavingsRate = monthlyIncome > 0
      ? (currentSavings / monthlyIncome) * 100
      : 0

    const currentPathRetirementAge = this.findRetirementAge(
      currentAge, currentNetWorth, currentSavings, fireNumber
    )

    const currentPath: PathDetail = {
      retirement_age: currentPathRetirementAge,
      savings_rate: round2(currentSavingsRate),
      monthly_savings: round2(currentSavings),
      feasibility: this.classifyFeasibility(currentSavingsRate),
    }

    // Check if target is achievable with current savings
    const futureNW = this.futureValue(currentNetWorth, currentSavings, yearsToRetirement * 12)
    const isAchievable = futureNW >= fireNumber

    if (isAchievable) {
      // Phase 0: Goal achievable with current savings rate
      const requiredMonthly = this.requiredMonthlySavings(currentNetWorth, fireNumber, yearsToRetirement)
      const requiredRate = monthlyIncome > 0 ? (requiredMonthly / monthlyIncome) * 100 : 0

      // Compute phase_sub for Phase 0
      let phaseSub: string
      if (gapToFire <= 0) {
        phaseSub = '0a'  // Already financially free
      } else if (currentPathRetirementAge < targetRetirementAge) {
        phaseSub = '0c'  // Ahead of schedule
      } else {
        phaseSub = '0b'  // On track
      }

      // Plan A for Phase 0: what it takes to retire at target age
      const planA: PathDetail = {
        retirement_age: targetRetirementAge,
        savings_rate: round2(requiredRate),
        monthly_savings: round2(requiredMonthly),
        feasibility: this.classifyFeasibility(requiredRate),
      }

      return {
        phase: 0,
        phase_sub: phaseSub,
        strategy: 'goal_achievable',
        fire_number: round2(fireNumber),
        gap_to_fire: round2(gapToFire),
        required_monthly_contribution: round2(requiredMonthly),
        required_savings_rate: round2(requiredRate),
        years_to_retirement: yearsToRetirement,
        is_achievable: true,
        current_path: currentPath,
        plan_a: planA,
        plan_b: null,
        recommended: null,
      }
    }

    // Not achievable with current savings — compute alternatives

    // Plan A: Keep target age, how much savings needed?
    const planAMonthlySavings = this.requiredMonthlySavings(currentNetWorth, fireNumber, yearsToRetirement)
    const planASavingsRate = monthlyIncome > 0 ? (planAMonthlySavings / monthlyIncome) * 100 : 100

    const planA: PathDetail = {
      retirement_age: targetRetirementAge,
      savings_rate: round2(planASavingsRate),
      monthly_savings: round2(planAMonthlySavings),
      feasibility: this.classifyFeasibility(planASavingsRate),
    }

    // Plan B: Keep current savings rate, when do we retire?
    const planBRetirementAge = this.findRetirementAge(
      currentAge, currentNetWorth, currentSavings, fireNumber
    )

    const planB: PathDetail = {
      retirement_age: planBRetirementAge,
      savings_rate: round2(currentSavingsRate),
      monthly_savings: round2(currentSavings),
      feasibility: this.classifyFeasibility(currentSavingsRate),
    }

    // Recommended: balanced — start at midpoint, auto-shift up until savings rate ≤ 60%
    let midAge = Math.round((targetRetirementAge + planBRetirementAge) / 2)
    midAge = Math.max(midAge, targetRetirementAge + 1)

    let midYears = Math.max(midAge - currentAge, 1)
    let midMonthlySavings = this.requiredMonthlySavings(currentNetWorth, fireNumber, midYears)
    let midSavingsRate = monthlyIncome > 0 ? (midMonthlySavings / monthlyIncome) * 100 : 100

    // Auto-shift: push age up until savings rate ≤ 60% (aggressive threshold)
    // Upper bound is 75 (absolute max), NOT planBAge
    let iterations = 50
    while (midSavingsRate > 60 && midAge < 75 && iterations > 0) {
      midAge++
      midYears = midAge - currentAge
      midMonthlySavings = this.requiredMonthlySavings(currentNetWorth, fireNumber, midYears)
      midSavingsRate = monthlyIncome > 0 ? (midMonthlySavings / monthlyIncome) * 100 : 100
      iterations--
    }

    // Deduplicate: if recommended lands on same age as planA or planB, set null
    const showRecommended =
      midAge !== targetRetirementAge &&
      midAge !== planBRetirementAge

    const recommended: PathDetail | null = showRecommended ? {
      retirement_age: midAge,
      savings_rate: round2(midSavingsRate),
      monthly_savings: round2(midMonthlySavings),
      feasibility: this.classifyFeasibility(midSavingsRate),
    } : null

    // Determine phase and phase_sub
    // Phase 1: adjustable (Plan A savings rate <= 60%)
    // Phase 2: impossible (Plan A savings rate > 60%)
    const phase: 1 | 2 = planASavingsRate <= 60 ? 1 : 2
    const strategy = phase === 1 ? 'user_choice' : 'impossible'

    // Compute phase_sub
    const ageGap = currentPathRetirementAge - targetRetirementAge
    let phaseSub: string
    if (ageGap <= 5 && planASavingsRate <= 40) {
      phaseSub = '0d'  // Within reach — small bump gets you there
    } else if (planASavingsRate <= 60) {
      phaseSub = '1'   // Stretching but possible
    } else {
      phaseSub = '2'   // Unrealistic target
    }

    return {
      phase,
      phase_sub: phaseSub,
      strategy,
      fire_number: round2(fireNumber),
      gap_to_fire: round2(gapToFire),
      required_monthly_contribution: round2(planAMonthlySavings),
      required_savings_rate: round2(planASavingsRate),
      years_to_retirement: yearsToRetirement,
      is_achievable: false,
      current_path: currentPath,
      plan_a: planA,
      plan_b: planB,
      recommended,
    }
  }
}

function round2(value: number): number {
  return Math.round(value * 100) / 100
}
