# Engineering Spec: Flamora Home / Plan System Rebuild
**Date:** 2026-04-07
**Branch:** `codex/home-plan-rebuild`
**Based on:** CEO Review `2026-04-07-flamora-home-plan-rebuild-ceo-review.md`
**Status:** Pre-implementation lock-in. No product code changed yet.

---

## 0. Purpose

This document converts the CEO plan into implementable engineering contracts.
It specifies every new data model, every API change, migration shape, and the safest build order.
All sections are derived from direct code inspection — not from assumptions.

**Read the CEO review first.** This document only records what the CEO review
implies for the engineering layer, plus every gap found in the current code.

---

## 1. Current State Audit — Key Gaps

### 1.1 `save-fire-goal` (TS) — Hard blockers

```
Validation (line 157-173) REQUIRES:
  current_age            (18..100, non-optional)
  target_retirement_age  (> current_age, non-optional)
  fire_number            (> 0, non-optional)
  required_savings_rate  (>= 0, non-optional)
  selected_plan          (one of: current | plan_a | plan_b | recommended)
```

**Problem:** v1 minimum goal setup omits `target_retirement_age`.
The validator will reject any goal without it.
This is the single highest-priority backend blocker.

### 1.2 `get-active-fire-goal` (TS)

- `years_remaining` is computed as `target_retirement_age - current_age` (line 80).
  If `target_retirement_age` is absent (v1 goal), this produces `NaN`.
- Does not return `official_fire_date`, `official_fire_age`, active plan metadata,
  or any progress status copy. The Hero card can't show what the CEO wants without
  these fields.

### 1.3 `generate-plans` (TS)

- Outputs only `savings_rate` + portfolio projections at 1/5/10 years.
- Does not output: `official_fire_date`, `official_fire_age`, `spending_ceiling`,
  `tradeoff_note`, `positioning_copy`.
- Plans are pure savings-compression math — not yet "relative to FIRE goal."

### 1.4 iOS `APIFireGoal` (mockdata.swift:758)

```swift
struct APIFireGoal: Codable {
    let targetRetirementAge: Int    // non-optional — crashes if field absent
    let currentAge: Int             // non-optional
    // Missing: officialFireDate, progressStatus, activePlanType, activePlanLabel
}
```

Decoding will throw if `target_retirement_age` is absent from the API.

### 1.5 `SimulatorView` — Still on mock data

```swift
// SimulatorView.swift:38-48
static func fromAPI() -> SimulatorSettings {
    let profile = MockData.apiUserProfile        // ← fake data
    let fireGoal = MockData.apiFireGoal          // ← fake data
    ...
}
```

No real API integration. No official / sandbox separation.

### 1.6 `JourneyView` — No state machine

- Uses `@AppStorage(FlamoraStorageKey.budgetSetupCompleted)` as a single boolean gate.
- No S0–S5 state machine.
- No guided setup card.
- No action strip.
- `FIRECountdownCard` has only two rendered paths: `isConnected=false` (empty) and
  `isConnected=true` (loaded or skeleton). No pre-goal state.

### 1.7 Setup flow — No goal step, no resume

- `BudgetSetupViewModel.Step` starts at `accountSelection` (step 0).
- No `goalSetup` step.
- No setup state persisted to backend — user who closes mid-flow starts over.
- `plaidManager.showBudgetSetup = true` is the only entry point.

### 1.8 Missing tables / entities

Neither `user_setup_state` nor `active_plans` exists in any referenced code.

---

## 2. New Setup State Machine

### 2.1 States

| State | Name | Condition | Home Hero | Supporting Block | Primary CTA |
|-------|------|-----------|-----------|-----------------|-------------|
| S0 | `noGoal` | No fire_goal row | teaser | Guided Setup Card — "Set your FIRE goal" | `Set my goal` |
| S1 | `goalSet` | fire_goal exists, no Plaid | goal-aware teaser | Guided Setup Card — "Connect your accounts" | `Connect accounts` |
| S2 | `accountsLinked` | Plaid linked, accounts not reviewed | partial Hero | Guided Setup Card — "Review connected accounts" | `Review accounts` |
| S3 | `snapshotPending` | Accounts reviewed, snapshot not seen | partial Hero | Guided Setup Card — "See where you stand" | `See my snapshot` |
| S4 | `planPending` | Snapshot seen, no active plan | partial Hero | Guided Setup Card — "Choose your path" | `Choose a plan` |
| S5 | `active` | Active plan exists | full official Hero | Action Strip (Save / Budget / Invest) | none |

### 2.2 iOS enum

```swift
// New file: Models/HomeSetupState.swift
enum HomeSetupState: String, Codable {
    case noGoal
    case goalSet
    case accountsLinked
    case snapshotPending
    case planPending
    case active
}
```

### 2.3 Source of truth

State is derived server-side from `get-setup-state` (new endpoint).
iOS reads it on Home appear and caches in memory (not `@AppStorage`).
`@AppStorage("budgetSetupCompleted")` remains for backward compat but is no
longer the primary gating mechanism for Home rendering.

---

## 3. Official Hero Data Model

### 3.1 iOS struct (replaces `APIFireGoal`)

```swift
// Models/HomeHeroModel.swift  — NEW FILE
struct HomeHeroModel: Codable {

    // --- Identity ---
    let goalId: String
    let dataSource: String          // "plaid" | "manual"

    // --- Progress (always present) ---
    let fireNumber: Double
    let currentNetWorth: Double
    let progressPercentage: Double  // 0..100
    let gapToFire: Double

    // --- Official FIRE estimates ---
    let officialFireDate: String?   // "Mar 2042" — nil if no active plan
    let officialFireAge: Int?       // nil if age unknown
    let yearsRemaining: Int?        // nil if no active plan
    let onTrack: Bool

    // --- Status copy (1 line, Hero voice) ---
    let progressStatus: String      // e.g. "Your current path is improving"

    // --- Active plan metadata ---
    let activePlanType: String?     // "steady" | "recommended" | "accelerate" | nil
    let activePlanLabel: String?    // "Recommended" — display label
    let savingsTargetMonthly: Double?

    // --- Legacy compat (kept for transition) ---
    let targetRetirementAge: Int?   // optional — v1 goals may omit
    let currentAge: Int?            // optional — derived if absent
    let requiredSavingsRate: Double?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case goalId = "goal_id"
        case dataSource = "data_source"
        case fireNumber = "fire_number"
        case currentNetWorth = "current_net_worth"
        case progressPercentage = "progress_percentage"
        case gapToFire = "gap_to_fire"
        case officialFireDate = "official_fire_date"
        case officialFireAge = "official_fire_age"
        case yearsRemaining = "years_remaining"
        case onTrack = "on_track"
        case progressStatus = "progress_status"
        case activePlanType = "active_plan_type"
        case activePlanLabel = "active_plan_label"
        case savingsTargetMonthly = "savings_target_monthly"
        case targetRetirementAge = "target_retirement_age"
        case currentAge = "current_age"
        case requiredSavingsRate = "required_savings_rate"
        case createdAt = "created_at"
    }
}
```

### 3.2 Transition strategy for `APIFireGoal`

Keep `APIFireGoal` struct alive during transition.
After `get-active-fire-goal` is updated, add new optional fields to `APIFireGoal`
and migrate `FIRECountdownCard` to use `HomeHeroModel`.
Delete `APIFireGoal` only after `FIRECountdownCard` and `JourneyView` are fully migrated.

---

## 4. Active Plan Data Model

### 4.1 iOS struct

```swift
// Models/ActivePlanModel.swift  — NEW FILE
struct ActivePlanModel: Codable {
    let planId: String
    let planType: String            // "steady" | "recommended" | "accelerate"
    let planLabel: String           // Display: "Steady" | "Recommended" | "Accelerate"
    let savingsTargetMonthly: Double
    let savingsRateTarget: Double   // percentage
    let spendingCeilingMonthly: Double
    let fixedBudgetMonthly: Double
    let flexibleBudgetMonthly: Double
    let officialFireDate: String?   // e.g. "Mar 2042"
    let officialFireAge: Int?
    let tradeoffNote: String
    let positioningCopy: String     // e.g. "A realistic step that moves FIRE meaningfully closer."
    let isActive: Bool
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case planId = "plan_id"
        case planType = "plan_type"
        case planLabel = "plan_label"
        case savingsTargetMonthly = "savings_target_monthly"
        case savingsRateTarget = "savings_rate_target"
        case spendingCeilingMonthly = "spending_ceiling_monthly"
        case fixedBudgetMonthly = "fixed_budget_monthly"
        case flexibleBudgetMonthly = "flexible_budget_monthly"
        case officialFireDate = "official_fire_date"
        case officialFireAge = "official_fire_age"
        case tradeoffNote = "tradeoff_note"
        case positioningCopy = "positioning_copy"
        case isActive = "is_active"
        case createdAt = "created_at"
    }
}
```

---

## 5. Simulator Preview Data Model

### 5.1 iOS struct

```swift
// Models/SimulatorPreviewModel.swift  — NEW FILE
struct SimulatorPreviewModel: Codable {
    let mode: String                // "demo" | "official_preview"

    // Official baseline (nil in demo mode)
    let officialFireDate: String?
    let officialFireAge: Int?
    let officialFireNumber: Double?

    // Preview result
    let previewFireDate: String
    let previewFireAge: Int
    let previewFireNumber: Double
    let deltaMonths: Int            // preview - official (negative = faster)
    let deltaYears: Double          // convenience

    // Graph series — two lines
    let officialPath: [SimulatorDataPoint]   // empty in demo mode
    let adjustedPath: [SimulatorDataPoint]

    enum CodingKeys: String, CodingKey {
        case mode
        case officialFireDate = "official_fire_date"
        case officialFireAge = "official_fire_age"
        case officialFireNumber = "official_fire_number"
        case previewFireDate = "preview_fire_date"
        case previewFireAge = "preview_fire_age"
        case previewFireNumber = "preview_fire_number"
        case deltaMonths = "delta_months"
        case deltaYears = "delta_years"
        case officialPath = "official_path"
        case adjustedPath = "adjusted_path"
    }
}

struct SimulatorDataPoint: Codable {
    let year: Int
    let netWorth: Double

    enum CodingKeys: String, CodingKey {
        case year
        case netWorth = "net_worth"
    }
}
```

### 5.2 Input contract (sent to `preview-simulator`)

```swift
// Models/SimulatorInputModel.swift  — NEW FILE
struct SimulatorPreviewRequest: Encodable {
    let mode: String                        // "demo" | "official_preview"

    // Official plan anchors (optional — for official_preview mode)
    let officialSavingsMonthly: Double?
    let officialRetirementSpending: Double?
    let officialNetWorth: Double?
    let officialAge: Int?

    // Sandbox overrides
    let sandboxSavingsMonthly: Double?
    let sandboxRetirementSpending: Double?
    let sandboxReturnRate: Double?          // default 7.0%
    let sandboxInflationRate: Double?       // default 3.0%
    let sandboxWithdrawalRate: Double?      // default 4.0%
    let sandboxTargetAge: Int?              // optional — sandbox only

    enum CodingKeys: String, CodingKey {
        case mode
        case officialSavingsMonthly = "official_savings_monthly"
        case officialRetirementSpending = "official_retirement_spending"
        case officialNetWorth = "official_net_worth"
        case officialAge = "official_age"
        case sandboxSavingsMonthly = "sandbox_savings_monthly"
        case sandboxRetirementSpending = "sandbox_retirement_spending"
        case sandboxReturnRate = "sandbox_return_rate"
        case sandboxInflationRate = "sandbox_inflation_rate"
        case sandboxWithdrawalRate = "sandbox_withdrawal_rate"
        case sandboxTargetAge = "sandbox_target_age"
    }
}
```

---

## 6. Edge Function Changes

### 6.1 `save-fire-goal` — REWRITE REQUIRED

**Problem:** Current validator requires `target_retirement_age` and `selected_plan`
in the old plan-name format (`current | plan_a | plan_b | recommended`).
v1 minimum goal needs neither.

**New v1 request schema:**

```typescript
interface SaveFireGoalRequestV2 {
  // v1 minimum required
  retirement_spending_monthly: number     // desired monthly spend in retirement
  lifestyle_preset: 'lean' | 'current' | 'fat'

  // computed by client or server
  fire_number?: number                    // if absent, server computes as spending * 12 * 25

  // optional — present only if user provided in sandbox/advanced flow
  target_retirement_age?: number
  current_age?: number                    // needed for FIRE date estimate

  // optional assumptions (server uses defaults if absent)
  withdrawal_rate_assumption?: number     // default 0.04
  inflation_assumption?: number           // default 0.03
  return_assumption?: number              // default 0.07
}
```

**Stored fields added to `fire_goals` table:**

```sql
ALTER TABLE fire_goals
  ADD COLUMN retirement_spending_monthly NUMERIC,
  ADD COLUMN lifestyle_preset TEXT,           -- 'lean' | 'current' | 'fat'
  ADD COLUMN withdrawal_rate_assumption NUMERIC DEFAULT 0.04,
  ADD COLUMN inflation_assumption NUMERIC DEFAULT 0.03,
  ADD COLUMN return_assumption NUMERIC DEFAULT 0.07;

-- Make formerly-required fields optional
ALTER TABLE fire_goals
  ALTER COLUMN target_retirement_age DROP NOT NULL,
  ALTER COLUMN current_age DROP NOT NULL;
```

**Backward compat rule:** Old rows with `target_retirement_age` continue to work.
`save-fire-goal` v2 accepts old fields silently if provided, ignores them for
FIRE number computation if `retirement_spending_monthly` is present.

---

### 6.2 `get-active-fire-goal` — EXTEND to Official Hero source

**Must add to response:**

```typescript
// New fields on data object:
official_fire_date: string | null        // "Mar 2042"
official_fire_age: number | null         // 47  (null if age unknown)
progress_status: string                  // "Your current path is improving"
active_plan_type: string | null          // "recommended" | null
active_plan_label: string | null         // "Recommended" | null
savings_target_monthly: number | null    // from active_plans table

// years_remaining — v1 compat fix:
// If target_retirement_age absent, compute from active plan's official_fire_age
// If that's also absent, return null (not NaN)
```

**FIRE date computation when age is absent:**

Use `retirement_spending_monthly` → compute `fire_number` → compute years using
current `monthly_savings_target` from active plan (if present) or
`required_monthly_contribution` from goal → project using real return rate.

```typescript
function computeFireDate(
  fireNumber: number,
  currentNetWorth: number,
  monthlySavings: number,       // from active plan or goal
  returnRate: number = 0.07
): { fireDate: string; fireAge: number | null; yearsRemaining: number } {
  // Standard FV formula, month-by-month
  // Returns ISO-month string + integer year count
}
```

---

### 6.3 `generate-plans` — EXTEND to FIRE-aware output

**Add to each plan in response:**

```typescript
interface PlanDetailV2 extends PlanDetail {
  // New fields
  savings_ceiling_monthly: number        // = monthly_spend (already exists as monthly_spend — alias for clarity)
  spending_ceiling_monthly: number       // same as monthly_spend but named clearly
  official_fire_date: string | null      // projected FIRE date at this plan's savings rate
  official_fire_age: number | null       // projected FIRE age at this plan's savings rate
  tradeoff_note: string                  // e.g. "Cuts $420/mo from discretionary. 3.2 years faster."
  positioning_copy: string               // e.g. "A realistic step that moves FIRE meaningfully closer."
  fire_years_vs_baseline: number         // years sooner than doing nothing
}
```

**`positioning_copy` rules:**

```typescript
function getPositioningCopy(planKey: 'steady' | 'recommended' | 'accelerate'): string {
  const copy = {
    steady: "Closest to how you live today.",
    recommended: "A realistic step that moves FIRE meaningfully closer.",
    accelerate: "The fastest path, with real tradeoffs.",
  }
  return copy[planKey]
}
```

**FIRE date computation:** Use same function as `get-active-fire-goal`.
Input is `current_net_worth` + plan's `monthly_save` + goal's `fire_number`.
If goal's `fire_number` is absent, use `retirement_spending_monthly * 12 * 25`.

**New required request field:** Add `fire_number` (optional — server falls back to
`user_profiles.fire_number` or computes from goal if absent).

---

### 6.4 `generate-spending-plan` — REPOSITION (minor changes only)

Current function works well. v1 changes:

- Accept `active_plan_id` optional field to mark this as plan-application context vs preview.
- If `active_plan_id` provided, persist result to `active_plans` (or return a
  `apply-selected-plan`-compatible payload instead).
- Remove `month` as required field (default to current month).
- Do NOT force category-level budget in v1 — `flexible_budget.items` stays in
  response but is labeled advisory, not binding.

---

### 6.5 NEW: `get-setup-state`

**Purpose:** Tell Home which setup state the user is in, and where to resume.

**Request:** GET (no body) — auth header only.

**Response:**

```typescript
{
  success: true,
  data: {
    setup_stage: 'no_goal' | 'goal_set' | 'accounts_linked' | 'snapshot_pending' | 'plan_pending' | 'active',
    last_incomplete_stage: string | null,  // where to resume

    // Checkpoints
    goal_completed_at: string | null,      // ISO timestamp
    accounts_reviewed_at: string | null,
    snapshot_reviewed_at: string | null,
    plan_selected_at: string | null,
    plan_applied_at: string | null,

    // IDs for deep-linking
    active_plan_id: string | null,
    active_goal_id: string | null,
  }
}
```

**Derivation logic (server-side, no new table required in v1):**

```typescript
// 1. Check fire_goals for active goal → if none: 'no_goal'
// 2. Check user_profiles.has_linked_bank → if false: 'goal_set'
// 3. Check user_setup_state.accounts_reviewed_at → if null: 'accounts_linked'
// 4. Check user_setup_state.snapshot_reviewed_at → if null: 'snapshot_pending'
// 5. Check active_plans for is_active row → if none: 'plan_pending'
// 6. All checks pass: 'active'
```

**Migration required (minimal):**

```sql
CREATE TABLE IF NOT EXISTS user_setup_state (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id),
  accounts_reviewed_at TIMESTAMPTZ,
  snapshot_reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

---

### 6.6 NEW: `apply-selected-plan`

**Purpose:** Convert a chosen plan (from `generate-plans` output) into the
official active plan. Single source of truth for "plan is now official."

**Request:**

```typescript
{
  plan_type: 'steady' | 'recommended' | 'accelerate',
  savings_target_monthly: number,
  savings_rate_target: number,
  spending_ceiling_monthly: number,
  fixed_budget_monthly: number,
  flexible_budget_monthly: number,
  official_fire_date: string | null,
  official_fire_age: number | null,
  tradeoff_note: string,
  positioning_copy: string,
}
```

**Server actions:**
1. Deactivate existing active plan (`active_plans.is_active = false`).
2. Insert new row into `active_plans`.
3. Write `user_setup_state.plan_applied_at`.
4. Return new `ActivePlanModel` + updated `HomeHeroModel` summary.

**Migration required:**

```sql
CREATE TABLE IF NOT EXISTS active_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  plan_type TEXT NOT NULL,           -- 'steady' | 'recommended' | 'accelerate'
  plan_label TEXT NOT NULL,
  savings_target_monthly NUMERIC NOT NULL,
  savings_rate_target NUMERIC NOT NULL,
  spending_ceiling_monthly NUMERIC NOT NULL,
  fixed_budget_monthly NUMERIC NOT NULL,
  flexible_budget_monthly NUMERIC NOT NULL,
  official_fire_date TEXT,           -- "Mar 2042"
  official_fire_age INT,
  tradeoff_note TEXT,
  positioning_copy TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX ON active_plans(user_id, is_active);
```

---

### 6.7 NEW: `preview-simulator`

**Purpose:** Power both demo and real sandbox simulator.
Must never write to official state.

**Request:** `SimulatorPreviewRequest` (see §5.2).

**Response:** `SimulatorPreviewModel` (see §5.1).

**Logic:**

```typescript
// demo mode:
//   Use provided sandbox overrides (or hardcoded defaults).
//   No access to user's real data.
//   official_path: []
//   official_fire_date: null

// official_preview mode:
//   Load user's active plan + fire goal for official anchors.
//   Apply sandbox overrides on top.
//   Compute both official path and adjusted path.
//   Compute delta_months = adjusted_fire_months - official_fire_months
```

Graph points: annual snapshots, 40 years or until FIRE number reached + 5 years.

---

## 7. Migrations Summary

### 7.1 Required for Phase 1 (backend contracts)

```sql
-- 1. Extend fire_goals
ALTER TABLE fire_goals
  ADD COLUMN IF NOT EXISTS retirement_spending_monthly NUMERIC,
  ADD COLUMN IF NOT EXISTS lifestyle_preset TEXT,
  ADD COLUMN IF NOT EXISTS withdrawal_rate_assumption NUMERIC DEFAULT 0.04,
  ADD COLUMN IF NOT EXISTS inflation_assumption NUMERIC DEFAULT 0.03,
  ADD COLUMN IF NOT EXISTS return_assumption NUMERIC DEFAULT 0.07;

ALTER TABLE fire_goals
  ALTER COLUMN target_retirement_age DROP NOT NULL,
  ALTER COLUMN current_age DROP NOT NULL;

-- 2. Create user_setup_state
CREATE TABLE IF NOT EXISTS user_setup_state (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id),
  accounts_reviewed_at TIMESTAMPTZ,
  snapshot_reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Create active_plans
CREATE TABLE IF NOT EXISTS active_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  plan_type TEXT NOT NULL,
  plan_label TEXT NOT NULL,
  savings_target_monthly NUMERIC NOT NULL,
  savings_rate_target NUMERIC NOT NULL,
  spending_ceiling_monthly NUMERIC NOT NULL,
  fixed_budget_monthly NUMERIC NOT NULL,
  flexible_budget_monthly NUMERIC NOT NULL,
  official_fire_date TEXT,
  official_fire_age INT,
  tradeoff_note TEXT,
  positioning_copy TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX ON active_plans(user_id, is_active);
```

### 7.2 No migration needed (for now)

- `monthly_budgets` table — unchanged; `generate-spending-plan` still writes here via `generate-monthly-budget`.
- `user_profiles` — unchanged; `has_linked_bank`, `plaid_net_worth` remain as-is.
- `plaid_items`, `plaid_accounts`, `transactions` — no changes.

---

## 8. API Contract Table: Keep / Extend / Rewrite / Add / Deprecate

| Edge Function | Action | Notes |
|---|---|---|
| `create-link-token` | **Keep** | No changes |
| `exchange-public-token` | **Keep** | No changes |
| `get-plaid-accounts` | **Keep** | No changes |
| `get-transactions` | **Keep** | No changes |
| `get-net-worth-summary` | **Keep** | No changes |
| `get-portfolio-history` | **Keep** | No changes |
| `get-account-balance-history` | **Keep** | No changes |
| `get-investment-holdings` | **Keep** | No changes |
| `get-spending-summary` | **Keep** | No changes |
| `get-monthly-budget` | **Keep** | Used by CashFlow for budget execution |
| `save-savings-checkin` | **Keep** | No changes |
| `generate-monthly-budget` | **Keep** (for now) | Still used by `saveFinalBudget()`. Deprecate after `apply-selected-plan` is live. |
| `calculate-spending-stats` | **Keep + minor** | Verify 6-month logic. Add `snapshot_summary` field for step D. |
| `generate-financial-diagnosis` | **Keep + shrink** | Reduce verbosity. Return 1 summary insight. Keep deterministic rules. |
| `get-user-profile` | **Keep** | Used by BudgetSetupViewModel. No changes needed now. |
| `save-fire-goal` | **Rewrite** | Remove required age fields. Add retirement_spending_monthly + lifestyle_preset. |
| `get-active-fire-goal` | **Extend** | Add official_fire_date, official_fire_age, progress_status, active_plan fields. |
| `generate-plans` | **Extend** | Add official FIRE date/age per plan. Add spending_ceiling, tradeoff_note, positioning_copy, fire_years_vs_baseline. |
| `generate-spending-plan` | **Extend** | Accept optional active_plan_id. Keep existing math. Remove month as required. |
| `get-setup-state` | **NEW** | Drive Home state machine. |
| `apply-selected-plan` | **NEW** | Turn chosen plan into official active plan. |
| `preview-simulator` | **NEW** | Power demo + real sandbox. Never writes official state. |

### Deprecated after Phase 2

- `calculate-fire-goal` (V1) — already superseded by `generate-plans`.
- `generate-monthly-budget` (V1) — superseded by `apply-selected-plan` + `generate-spending-plan`.

---

## 9. iOS Client Changes Summary

### 9.1 New files

| File | Purpose |
|---|---|
| `Models/HomeSetupState.swift` | `HomeSetupState` enum S0–S5 |
| `Models/HomeHeroModel.swift` | Official Hero data model |
| `Models/ActivePlanModel.swift` | Active plan read model |
| `Models/SimulatorPreviewModel.swift` | Simulator preview + graph model |
| `Models/SimulatorInputModel.swift` | Simulator preview request |

### 9.2 Modified files (data layer only, no UI changes in this phase)

| File | Change |
|---|---|
| `Services/APIService.swift` | Add `getSetupState()`, `applySelectedPlan()`, `previewSimulator()`, `getHomeHero()` |
| `Services/APIService+BudgetSetup.swift` | Update `generatePlans()` request/response types |
| `Models/BudgetSetupModels.swift` | Extend `PlanDetail` with `officialFireDate`, `officialFireAge`, `tradeoffNote`, `positioningCopy`, `fireYearsVsBaseline` |
| `Models/mockdata.swift` | Add `SimulatorInputModel` defaults for demo mode |

### 9.3 `APIFireGoal` — transition plan

1. Add new optional fields to `APIFireGoal` (keeps decoder from crashing).
2. Decode new fields from extended `get-active-fire-goal` response.
3. `FIRECountdownCard` begins using new fields alongside old ones.
4. After Home is rebuilt, migrate `JourneyView` to use `HomeHeroModel` instead.
5. Delete `APIFireGoal` in cleanup pass.

---

## 10. Safest Implementation Order

### Phase 1: Data contracts + migrations (no UI changes)

> Goal: All new tables and field extensions live in prod. All new Edge Functions deployed.
> iOS client can call them safely — new optional fields don't break old decoders.

1. Run migrations: extend `fire_goals`, create `user_setup_state`, create `active_plans`.
2. Update `save-fire-goal`: make `target_retirement_age` optional, add new fields.
3. Extend `get-active-fire-goal`: add new optional response fields.
4. Extend `generate-plans`: add FIRE date/age per plan, tradeoff_note, positioning_copy.
5. Deploy `get-setup-state` (new function, safe to deploy before iOS uses it).
6. Deploy `apply-selected-plan` (new function, safe to deploy before iOS uses it).
7. Deploy `preview-simulator` (new function, safe to deploy before iOS uses it).
8. Add new Swift model files (no UI wired yet).
9. Add new `APIService` methods (no calls made yet).
10. Extend `PlanDetail` / `BudgetSetupModels.swift` with new fields (all optional — no decode crashes).

**Verification:** All existing flows (BudgetSetup, CashFlow, Investment) continue to work exactly as before.

---

### Phase 2: Setup flow rebuild

> Goal: Resumable setup with correct step order. Goal step added before account step.

11. Add `HomeSetupState` to iOS.
12. Add `getSetupState()` call in `JourneyView.loadData()`. Store result in `@State var setupState`.
13. Add `GoalSetupView` (new lightweight screen — retirement spending + lifestyle preset).
14. Insert goal step as step 0 in `BudgetSetupViewModel.Step` enum (rename existing step 0 to `accountSelection`).
15. Wire `GoalSetupView` to call updated `save-fire-goal` v2.
16. Add `ConnectedAccountsReviewView` (step after account linking).
17. Wire `accounts_reviewed_at` write into `user_setup_state` via new helper.
18. Add `snapshot_reviewed_at` write when user taps "Continue" on diagnosis screen.
19. Implement resume: `BudgetSetupView` reads `last_incomplete_stage` and jumps to correct step.

---

### Phase 3: Home rebuild

> Goal: State-driven Home. Hero uses official data. Guided Setup Card and Action Strip.

20. Add `HomeHeroModel` decoder to `APIService.getActiveFireGoal()` (add method alongside existing one).
21. Rebuild `FIRECountdownCard` to accept `HomeHeroModel` instead of `APIFireGoal`.
    — Show `officialFireDate` and `officialFireAge` when available.
    — New state: `noGoal` teaser mode (no card, just goal prompt placeholder).
22. Add `GuidedSetupCard` component (shows correct copy + CTA based on `HomeSetupState`).
23. Add `ActionStrip` component (Save / Budget / Invest status row for S5).
24. Rebuild `JourneyView` state-driven switch:
    - S0–S4: `FIRECountdownCard` (partial/teaser) + `GuidedSetupCard`
    - S5: `FIRECountdownCard` (full) + `ActionStrip`
25. Remove `PortfolioCard` from top position in Home. Move to Investment tab entry or second-tier status only.
26. Remove `SavingsRateCard` from Home (moves to Cash Flow execution layer).
27. Remove daily quote card from primary flow (or demote to optional/below-the-fold).
28. Keep `@AppStorage("budgetSetupCompleted")` write on plan apply for backward compat.

---

### Phase 4: Simulator rebuild

> Goal: Official vs sandbox separation. Demo mode for pre-setup users.

29. Remove `SimulatorSettings.fromAPI()` dependency on `MockData`.
30. Implement `APIService.previewSimulator()` call.
31. Rebuild `SimulatorView` around `SimulatorPreviewModel`:
    - `mode: "official_preview"` when user is in S5 (has active plan).
    - `mode: "demo"` when user is in S0–S4 (no official data).
32. Label demo mode visibly with `"DEMO"` badge.
33. "Apply this scenario" CTA visible only in `official_preview` mode.
34. Slider changes update local `SimulatorPreviewRequest` state → debounced API call → update `SimulatorPreviewModel`.
35. Hero never changes when sliders move (official Hero fetched independently, never bound to simulator state).

---

### Phase 5: Cash Flow cleanup

> Goal: 3-card top level. Navigation depth ≤ 3.

36. Refactor `CashflowView` first screen to Income / Budget / Savings cards only.
37. Audit sheets and full-screen covers for accidental depth-4 navigation.
38. Align CTA language with official plan execution language.

---

### Phase 6: Investment alignment

> Goal: Copy and entry behavior aligned with new Home story.

39. Update `InvestmentView` copy to reference official FIRE progress.
40. Verify Invest strip item in Action Strip lands correctly in `InvestmentView`.
41. Audit empty / syncing / loading states for consistency.

---

## 11. Cache Invalidation Rules

| Trigger | Caches to invalidate |
|---|---|
| `apply-selected-plan` success | `HomeHeroModel`, `HomeSetupState`, `ActivePlanModel`, `APIMonthlyBudget` |
| Plaid account link success | `HomeSetupState`, `APINetWorthSummary`, `HomeHeroModel` |
| `accounts_reviewed_at` written | `HomeSetupState` |
| `snapshot_reviewed_at` written | `HomeSetupState` |
| Savings check-in | `APIMonthlyBudget`, Home Action Strip save status |
| Simulator slider change | `SimulatorPreviewModel` only — never `HomeHeroModel` |

---

## 12. Risk Register

| # | Risk | Mitigation |
|---|---|---|
| R1 | Existing users have `APIFireGoal` with `targetRetirementAge` — making it optional in Swift breaks their decode | Make field `Int?` and update `FIRECountdownCard` to use `officialFireAge` (new) with `targetRetirementAge` as fallback |
| R2 | `fire_goals.target_retirement_age DROP NOT NULL` on prod — existing rows all have values, safe | Verify in staging first; migration is a no-op for existing data |
| R3 | `generate-plans` FIRE date computation adds latency | Compute is O(n) months loop — negligible. Benchmark before worrying. |
| R4 | `preview-simulator` called on every slider change — API abuse | Debounce 400ms on client. Cache last result for unchanged inputs. |
| R5 | Home state machine S0–S5 derivation is slightly different between `get-setup-state` (server) and client-cached state | Always trust server state on `loadData()`. Client state is display-only between refreshes. |
| R6 | `generate-monthly-budget` (old) and `apply-selected-plan` (new) both write budget rows — race condition | `apply-selected-plan` replaces `generate-monthly-budget` for setup path. Old path remains for manual budget edits only. Document this clearly. |

---

## 13. What This Document Does NOT Cover

- CashFlow detailed view rebuilds (Phase 5 — minor, deferred)
- Investment information architecture (deferred per CEO review)
- Category-level budgeting UI (deferred — not a v1 setup promise)
- Notification / push logic for FIRE progress milestones
- Supabase RLS policies for new tables (must be added before deployment — security blocker)

**RLS reminder:** Before deploying `user_setup_state` and `active_plans`,
add `user_id = auth.uid()` policies. Both tables are user-scoped.
