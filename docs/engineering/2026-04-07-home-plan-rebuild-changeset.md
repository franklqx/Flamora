# Changeset: Home / Plan Rebuild — Backend Contracts + Swift Models
**Date:** 2026-04-07
**Build status:** SUCCEEDED
**Branch:** `codex/home-plan-rebuild`

No UI layout changed. All changes are data contracts, models, and API services.

---

## Files Changed

### New — Migrations
| File | Purpose |
|------|---------|
| `Fire cursor/supabase/migrations/20260407_rebuild_fire_goal_setup_state.sql` | Extends `fire_goals`, creates `user_setup_state`, creates `active_plans` |

### New — Shared TS Utility
| File | Purpose |
|------|---------|
| `Fire cursor/supabase/functions/_shared/fire-math.ts` | Shared FIRE date computation, fire number, progress status copy, graph series generator |

### New — Edge Functions
| File | Purpose |
|------|---------|
| `Fire cursor/supabase/functions/get-setup-state/index.ts` | Returns S0–S5 setup stage + resume pointer |
| `Fire cursor/supabase/functions/apply-selected-plan/index.ts` | Writes chosen plan to `active_plans`, stamps `user_setup_state.plan_applied_at` |
| `Fire cursor/supabase/functions/preview-simulator/index.ts` | Demo + official_preview simulator; never writes official state |

### Modified — Edge Functions
| File | Change |
|------|--------|
| `Fire cursor/supabase/functions/save-fire-goal/index.ts` | `target_retirement_age` now optional; `retirement_spending_monthly` + `lifestyle_preset` added as v1 minimum fields; backward compat with old requests preserved |
| `Fire cursor/supabase/functions/get-active-fire-goal/index.ts` | Parallel-fetches `active_plans`; computes official FIRE date from savings math (not age diff); adds `official_fire_date`, `official_fire_age`, `official_years_remaining`, `progress_status`, `active_plan_type/label`, `savings_target_monthly`; all v1 fields preserved |
| `Fire cursor/supabase/functions/generate-plans/index.ts` | Fetches `fire_number` from DB if not in request; adds per-plan `official_fire_date`, `official_fire_age`, `spending_ceiling_monthly`, `tradeoff_note`, `positioning_copy`, `fire_years_vs_baseline` |

### New — Swift Models
| File | Purpose |
|------|---------|
| `Models/HomeSetupState.swift` | `HomeSetupStage` enum (S0–S5), `HomeSetupStateResponse`, `GuidedSetupCardContent` |
| `Models/HomeHeroModel.swift` | Official Hero model (new fields + legacy compat); `displayFireDate` / `displayFireAge` helpers |
| `Models/ActivePlanModel.swift` | Active plan read model; `ApplyPlanRequest` with `from(planDetail:)` factory |
| `Models/SimulatorPreviewModel.swift` | Preview model + graph data points; `SimulatorPreviewRequest` with `demo()` / `officialPreview()` factories |

### Modified — Swift Models
| File | Change |
|------|--------|
| `Models/mockdata.swift` | `APIFireGoal`: `targetRetirementAge` and `currentAge` now `Int?`; v2 Hero fields added as `var = nil` (all optional, zero callsite impact) |
| `Models/BudgetSetupModels.swift` | `PlanDetail`: 6 new optional fields (`officialFireDate`, `officialFireAge`, `spendingCeilingMonthly`, `fireYearsVsBaseline`, `tradeoffNote`, `positioningCopy`); `GeneratePlansRequest`: 3 new optional fields (`fireNumber`, `retirementSpendingMonthly`, `returnAssumption`); `SaveFireGoalRequest` + `SaveFireGoalResponse` added |

### Modified — Services
| File | Change |
|------|--------|
| `Services/APIService.swift` | Added: `getHomeHero()`, `getSetupState()`, `applySelectedPlan()`, `previewSimulator()`, `markSetupStep()` |
| `Services/APIService+BudgetSetup.swift` | Added: `saveFireGoal(data:)` for v1 minimum goal flow; clarified `generatePlans` doc comment |

### Modified — Views (minimal — only to fix compile errors)
| File | Change |
|------|--------|
| `View/Journey/FIRECountdownCard.swift` | `fireDateLabel(yearsRemaining:)` → `fireDateLabel(goal:)` uses `officialFireDate` if present; legacy overload preserved |
| `View/Journey/SimulatorView.swift` | `age: fireGoal.currentAge` → `age: fireGoal.currentAge ?? 30` (compile fix for now-optional field) |

### Modified — Xcode Project
| File | Change |
|------|--------|
| `Flamora app.xcodeproj/project.pbxproj` | 4 new Swift files registered (PBXBuildFile + PBXFileReference + group + Sources) |

---

## Deployment Order (backend)

1. Run migration `20260407_rebuild_fire_goal_setup_state.sql`
2. Deploy `save-fire-goal` (rewrite — backward compat maintained)
3. Deploy `get-active-fire-goal` (extend — additive only)
4. Deploy `generate-plans` (extend — additive only)
5. Deploy `get-setup-state` (new)
6. Deploy `apply-selected-plan` (new)
7. Deploy `preview-simulator` (new)

Step 1 must run before steps 2–7. Steps 2–7 are safe to run in any order.

---

## What Is NOT Changed

- All existing UI layout (JourneyView, BudgetSetupView, SimulatorView content)
- BudgetSetupViewModel step logic
- CashflowView, InvestmentView
- All Plaid connection pipeline
- generate-spending-plan, generate-monthly-budget, generate-financial-diagnosis
- TabContentCache, PlaidManager
