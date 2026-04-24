# Budget Setup Handoff — 2026-04-25

Branch worked on: `claude/objective-curran-6afffc`

Push target requested by owner: `frankli/my-change-20260421`

This handoff captures what has been changed, what has been verified, and what remains intentionally unresolved so the next review can resume without re-discovering the same issues.

## Modified

### 1. Backend test coverage

- Added three spending-stat fixtures:
  - `Fire cursor/supabase/functions/_tests/fixtures/high-earner-near-fire.json`
  - `Fire cursor/supabase/functions/_tests/fixtures/wants-heavy.json`
  - `Fire cursor/supabase/functions/_tests/fixtures/big-rent-plus-travel.json`
- Extended `spending-stats.test.ts` for:
  - high earner near FIRE
  - wants-heavy category totals
  - large recurring rent vs one-time travel outlier behavior
  - monthly breakdown spend invariants across old and new fixtures
- Extended `plan-generation.test.ts` for:
  - `savingsRate * avgIncome == monthlySave`
  - `monthlySpendCeiling + monthlySave == avgIncome`
  - FIRE number calculation
  - `already_fire` behavior
  - max feasible save cap behavior

### 2. Plaid sandbox audit fixture

- Added `docs/plaid/sandbox-balanced-household-budget-setup.json`.
- Reason: the original sandbox JSON included investment account data that Plaid Dashboard schema validation rejected. The new fixture keeps the budget setup audit focused on checking/savings transactions.
- Added / updated `docs/plaid/budget-setup-audit-2026-04-24.md` with expected Reality / Plan / Category Limits checks and open risks.

### 3. Choose Plan page

- Reworked `BS_ChoosePathView.swift`.
- Current page shape:
  - title: `Choose Your Plan`
  - subtitle: `Pick a monthly budget and saving target.`
  - `TODAY` card is shown above target.
  - `YOUR TARGET` card sits below Today and can return to Target editing.
  - Plan card primary value is `SAVE`.
  - Plan card secondary metrics are `BUDGET`, `SAVING RATE`, and `FIRE AGE`.
  - Expanded details now use `Budget change`, `Saving rate change`, and `Progress boost`.
  - Bottom projection note was rewritten to be concise but clearer that figures are projections, not guaranteed returns.
- Removed the old custom slider / caps sheet from this page.

### 4. Category Limits page

- Added `BS_SplitBudgetView.swift` and routed Step 5.5 through it.
- The page is no longer a mandatory "Split Your Wants" allocation step.
- Current behavior:
  - title: `Set Category Limits`
  - subtitle: `Add optional limits for the categories you want to watch more closely.`
  - summary shows `Monthly budget`, `Save target`, and `Limits set`
  - section label is `OPTIONAL LIMITS`
  - each category row shows historical average and whether a limit is set
  - tapping a category opens a sheet to set, update, or remove a monthly limit
  - `Skip` clears category limits and continues
  - `Continue` keeps user-set limits and continues
- Important behavior change: the page no longer calls `ensureCategoryBudgetsSeeded()`, so suggested values are not automatically saved.
- Empty category limits are allowed. Category limits do not change total monthly budget.

### 5. Saving target and category budget persistence

- `BudgetSetupViewModel.swift` now carries Step 5.5 before Confirm.
- `saveFinalBudget()` canonicalizes `category_budgets` before save.
- Cashflow / Budget card code now reads the active plan's monthly savings target instead of depending only on the monthly budget row.
- Budget category keys are expected to be canonical ids such as `shopping`, `dining_out`, `travel`, `utilities`.

## Verified

- Deno unit suite previously passed after the fixture/test additions:
  - `41/41` tests passing across spending-stats, plan-generation, and fire-math alignment.
- Xcode build passed after the latest Category Limits page change:
  - command: `xcodebuild -project "Flamora app.xcodeproj" -scheme "Flamora app" -destination "generic/platform=iOS Simulator" -derivedDataPath /tmp/FlamoraDerived build`
  - result: `BUILD SUCCEEDED`
- Manual Supabase checks from the Plaid sandbox flow matched the expected transaction categories and monthly aggregates documented in `docs/plaid/budget-setup-audit-2026-04-24.md`.

## Not Modified Yet

### 1. FIRE starting balance

- Current FIRE math still uses `currentNetWorth` / manual net worth shape.
- Product decision: this should become investable portfolio balance / portfolio balance for more accurate FIRE projections.
- Not implemented in this branch yet because it affects account connection flow, onboarding, home progress, and backend payload contracts.

### 2. Home todo / account connection flow

- The desired future flow is not implemented yet:
  - ask users to connect cash / credit accounts for cash flow
  - ask users to connect investment accounts before using portfolio-sensitive FIRE projections
  - show Home todos that guide missing setup steps
- Current Cashflow and Investment entry points can still have separate connect-account CTAs.

### 3. Category Limits end-to-end database verification

- The UI now writes only user-set category limits.
- Still needs a simulator pass:
  - set one category limit, e.g. Shopping `$190`
  - finish Confirm
  - verify `active_plans.category_budgets` / monthly budget response only contains that chosen key
  - verify Cashflow budget UI displays the limit under the correct category

### 4. Deficit and near-FIRE Plaid Dashboard users

- Unit fixtures exist for high-earner / wants-heavy / big-rent-plus-travel behavior.
- Separate Plaid Dashboard sandbox users for deficit and near-FIRE scenarios were not created in this pass.

### 5. Reality vs Plan saving wording

- There is a product wording nuance still worth reviewing:
  - Reality may describe saving as cash-flow-based income minus spend.
  - Plan page uses the current monthly saving snapshot to compare against plan saving.
- If the displayed values diverge because median net saving and median income minus median spend differ, decide whether to expose the distinction or standardize the metric.

## Notes For Next Reviewer

- Do not reintroduce automatic allocation on Category Limits. The user explicitly wants category limits to be optional.
- Avoid the words `Wants`, `Split`, `Assigned`, `Remaining`, and `Use suggested` on the Category Limits page.
- Keep the portfolio / investment-account gating discussion separate from the current Category Limits review unless the owner explicitly asks to continue that larger flow work.
