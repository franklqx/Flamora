# CEO Review: Flamora — Home / Setup / Plan System Rebuild
Generated on 2026-04-07
Branch: `0331数据api版`
Mode: `SELECTIVE EXPANSION (with expansion lens)`
Repo: `Flamora`

---

## 1. Executive Summary

### One-line product thesis

Flamora should stop feeling like a finance dashboard and start feeling like a **FIRE operating system**:

- Home tells you **where your FIRE journey stands now**
- Cash Flow tells you **whether your behavior is matching the plan**
- Investment tells you **what your assets are doing**
- Simulator lets you **play with the future without corrupting reality**

### Core product shift

The rebuild is not “replace portfolio card with hero card.”

The rebuild is:

1. Redesign the **main product order**
2. Redesign the **state machine**
3. Redesign what is **official data** vs **sandbox data**
4. Redesign setup so it becomes one coherent flow instead of separate disconnected tools

### Final strategic decisions locked in

- Home becomes a **two-act screen**
  - Act 1 = `Reality`
  - Act 2 = `Sandbox`
- Hero’s subject is **FIRE progress**
- Hero always shows **official / real / current** data
- Simulator never silently rewrites the official Hero
- v1 onboarding does **not** collect `target age`
- v1 minimum goal input is:
  - `retirement spending`
  - `lifestyle preset` (`Lean / Current / Fat`)
- Plan engine outputs three dynamic paths:
  - `Steady`
  - `Recommended`
  - `Accelerate`
- Plan engine’s main output is **Savings Target**
- Budget is derived from Savings Target
- v1 budget system tracks **total budget + broad structure**, not detailed category budgeting as the main setup promise
- Setup must be **resumable**
- Pre-connection users can access a **Demo Simulator**

### Overall verdict

**This rebuild is worth doing.**

The current app already has a lot of capability, but the product story is split across too many surfaces:

- Home is half dashboard, half teaser
- Budget Setup is powerful but not yet the true operating flow
- Simulator is interesting but not yet correctly positioned
- Cash Flow and Investment have useful data but the product hierarchy is not yet crisp

This rebuild fixes the product narrative without throwing away the best engineering work already done.

---

## 2. What Changes vs What Stays

### What changes

#### Product architecture

- Home is fully rebuilt into a state-driven, two-act product surface
- Setup becomes one continuous flow:
  - `Minimum Goal Setup`
  - `Connect Accounts`
  - `Connected Accounts Review`
  - `Financial Snapshot / Reality Check`
  - `Choose Plan`
  - `Return to Home`
- The old idea of “budget setup as a separate isolated tool” is replaced by “plan selection as the app’s core setup moment”

#### Home information architecture

- Remove the old “portfolio-first + budget card + quote” logic from the top of Home
- Replace it with:
  - official FIRE Hero
  - guided setup card or action strip
  - pull-down sandbox simulator

#### FIRE logic

- Stop using onboarding age as a required input
- Move age from onboarding into output / simulator space
- Compute official FIRE progress from:
  - official goal inputs
  - official current net worth
  - official active plan

#### Budget logic

- Stop treating category budgeting as the first promise
- Start from Savings Target
- Let budget become the execution layer of the chosen plan

#### Frontend state model

- New users, resumed users, half-complete users, and fully configured users no longer share the same Home state

#### Backend / Edge Functions

- Existing budget functions are reused conceptually but their contracts need to be redesigned around:
  - setup state
  - active plan
  - official Hero
  - simulator preview

### What stays

#### Keep and reuse

- Plaid connection pipeline
- Trust Bridge
- existing Supabase + Edge Function architecture
- current account aggregation capability
- current portfolio / holdings / allocation capability
- current spending stats / diagnosis / plan generation foundations
- current budget math foundations
- current Cash Flow drill-down capability
- current Investment analysis capability
- current `APIService` approach and auth flow

#### Keep but reposition

- `BudgetPlanCard` ideas move into Cash Flow / execution surfaces
- `PortfolioCard` ideas move to Investment and Home’s `Invest` strip status, not the top of Home
- existing simulator math is kept as a foundation, but UI role and data source are rewritten

### What gets cut from the main path

- Portfolio as the top hero of Home
- Home as a stacked dashboard of unrelated cards
- forcing users to choose between parallel setup CTAs
- requiring `target age` in v1 onboarding
- making simulator the same thing as official progress

### What is deferred

- category-level budgeting as the main onboarding promise
- fully re-architecting Investment information hierarchy
- making every simulator scenario instantly become the official plan
- too many AI insights on setup screens

---

## 3. New Product Order

### Official setup flow

1. `Minimum Goal Setup`
2. `Connect Accounts`
3. `Connected Accounts Review`
4. `Financial Snapshot / Reality Check`
5. `Choose Plan`
6. `Apply Plan`
7. `Home`

### Sandbox flow

This is separate from the official setup flow.

- Pre-account users can access a `Demo Simulator`
- Post-setup users can access the real `Sandbox Simulator`
- Neither simulator mode silently changes official Hero data

### Product rule

**Reality and simulation must never be visually confused.**

That means:

- Hero = official reality
- Simulator result card = preview
- Graph in simulator = sandbox projection
- User must explicitly apply a plan for official progress to change

---

## 4. Home State Machine

### State table

| State | User condition | Hero | Supporting block | Primary CTA | Pull-down behavior |
|------|------|------|------|------|------|
| S0 | Brand new, no goal, no accounts | teaser Hero | guided setup card | `Set your goal` | demo simulator available |
| S1 | Goal saved, no accounts | goal-aware teaser Hero | guided setup card | `Connect accounts` | demo simulator available |
| S2 | Some accounts linked, setup incomplete | partial Hero | guided setup card | `Resume setup` | demo simulator or limited sandbox |
| S3 | Accounts linked, snapshot not reviewed | partial official Hero | guided setup card | `See my snapshot` | limited sandbox allowed |
| S4 | Snapshot reviewed, no plan applied | partial official Hero | guided setup card | `Choose a plan` | sandbox allowed |
| S5 | Plan applied, official state active | full official Hero | `Save / Budget / Invest` action strip | none or contextual secondary action | full sandbox allowed |

### State principles

- Home never shows two equal-priority setup CTAs
- Each incomplete state exposes exactly one main action
- Home should always make it obvious **what is missing**
- Resume state must know where the user dropped off

### Resume rules

- If user left during account linking:
  - show `Resume setup`
  - reopen account assembly flow
- If user linked accounts but never reviewed them:
  - show `Review connected accounts`
- If user completed review but not snapshot:
  - show `See my snapshot`
- If user completed snapshot but not plan:
  - show `Choose your plan`
- If user has a plan:
  - show full Home

---

## 5. Home Rebuild Spec

## 5.1 Act 1: Official Hero

### Purpose

Answer one question:

**How far am I from FIRE right now?**

### Hero content

Official Hero should show:

- FIRE progress %
- official FIRE date
- official FIRE age
- progress status
- a short supporting line

### What the Hero must not become

- not a portfolio card
- not a market hype card
- not a simulator result card
- not a generic finance dashboard

### Official calculation rules

Hero is based on:

- active FIRE goal profile
- active official plan
- current real net worth
- current real account data

Market movement may affect official outputs, but market movement should not hijack the Hero’s voice.

### Hero voice guidelines

Prefer:

- `You're 28% of the way there`
- `Estimated FIRE: Mar 2042`
- `Your current path is improving`

Avoid:

- over-celebrating random market moves as personal achievement
- overly technical explanations in the Hero itself

## 5.2 Pre-setup supporting block: Guided Setup Card

### Purpose

For incomplete users, Hero should be followed by a **Guided Setup Card**, not a compact strip.

### Why

Short labels like `Goal / Connect / Plan` are too abstract for incomplete users.

These users need:

- a full sentence
- one clear next step
- one primary CTA

### Card patterns

#### Goal missing

- Title: `Set your FIRE goal`
- Body: `Tell us what retirement should cost so we can estimate your real path.`
- CTA: `Set my goal`

#### Accounts missing

- Title: `Connect your accounts`
- Body: `Link checking, savings, credit, and investment accounts to reveal your real starting point.`
- CTA: `Connect accounts`

#### Snapshot pending

- Title: `See where you stand`
- Body: `We analyzed your finances. Review your snapshot before choosing a plan.`
- CTA: `See my snapshot`

#### Plan pending

- Title: `Choose your path`
- Body: `Pick the plan that fits your FIRE goal and current finances.`
- CTA: `Choose a plan`

## 5.3 Post-setup supporting block: Action Strip

### Purpose

After setup is complete, Hero should be followed by a compact strip with 3 levers:

- `Save`
- `Budget`
- `Invest`

### What each item shows

These are **status + number**, not just totals.

#### Save

- current month saved vs target
- example: `+$820 / $1,200`
- tap opens Savings / Cash Flow execution view

#### Budget

- this month vs plan
- example: `5% under plan`
- tap opens Budget execution view

#### Invest

- concise portfolio movement summary
- example: `+$2.1k this month`
- tap opens Investment

### Rule

The strip is a **lever summary**, not a second dashboard.

## 5.4 Act 2: Simulator / Sandbox

### Purpose

Answer a different question:

**If I change my behavior or assumptions, what happens?**

### Three-layer structure

1. `Result card`
2. `Before / After graph`
3. `Controls`

### Result card

Show:

- current official FIRE date
- simulated FIRE date
- delta in months / years
- `Apply this scenario` only if user is in post-setup real mode

### Graph

Show:

- current path
- adjusted path

Do not overload the chart with too many lines.

### Controls

#### Quick adjustments

- monthly savings / contribution
- retirement spending
- maybe a preset for lifestyle shift

#### Advanced assumptions

- return rate
- inflation rate
- withdrawal rate
- optional target age in sandbox only

### Demo Simulator

Pre-setup users can play a **Demo Simulator**.

Rules:

- must be visibly marked `Demo`
- must not be confused with official Hero
- may use sample data or minimum-goal inputs
- should exist to create wow factor, not to pretend precision

### Explicit separation rule

- Hero never changes just because a slider moved
- slider changes only update sandbox outputs
- official data changes only when the user explicitly applies a plan / saves a goal / changes real settings

---

## 6. Setup Flow Rebuild Spec

## 6.1 Step A: Minimum Goal Setup

### v1 input fields

- `desired retirement spending`
- `lifestyle preset`
  - `Lean`
  - `Current`
  - `Fat`

### v1 fields to exclude

- do not ask for target retirement age
- do not ask for a detailed category budget
- do not ask for too many simulator-like assumptions here

### Why

This keeps the input small and avoids the “fantasy number trap.”

Age should be output or sandbox input, not onboarding burden.

### Frontend tasks

- Create a new lightweight goal setup surface
- Replace current age-heavy framing with spending-based framing
- Keep copy very short
- Save incomplete progress

### Backend tasks

- Refactor goal payload shape
- Support a goal profile without `target_retirement_age`
- Store:
  - lifestyle preset
  - target retirement spending
  - setup completion state

## 6.2 Step B: Connect Accounts

### Product rule

This is one setup stage, not many separate mini-journeys.

### UX behavior

- user starts with one CTA: `Connect accounts`
- they can connect multiple institutions in one flow
- do not kick user back to Home after each institution

### Proposed flow

1. start Plaid
2. connect one institution
3. land on `Connected Accounts Review`
4. from there:
   - `Add another institution`
   - or `Continue`

### Frontend tasks

- build a setup-owned account assembly flow
- support multiple institution additions without losing context
- show connected institutions and account types
- track partial completion

### Backend tasks

- no major Plaid architecture rewrite required
- expose enough metadata to show:
  - institution
  - account type
  - last sync
  - selected account IDs

## 6.3 Step C: Connected Accounts Review

### Purpose

Build trust before plan selection.

### Content

- grouped list by account type:
  - checking
  - savings
  - credit
  - investment
- connection completeness
- `Add another institution`
- `Continue`

### Frontend tasks

- build a dedicated review page
- show clear grouping and sync state
- allow returning to Plaid link flow

### Backend tasks

- no new math required
- may need a cleaner aggregation endpoint or reuse `get-plaid-accounts`

## 6.4 Step D: Financial Snapshot / Reality Check

### Purpose

Tell the user:

**We understood your finances. Here is where you stand before we recommend a path.**

### Content

- 3 core metrics:
  - Income
  - Spending
  - Savings
- 1 six-month trend
- 1 short insight
- CTA to choose a plan

### Keep it short

Do not turn this into a reporting dashboard.

### Insight rules

- one headline insight line on the page
- if needed, tiny one-line sub-captions on metric cards later
- no long AI paragraphs

### Frontend tasks

- reuse current diagnosis work
- rewrite the page around trust and clarity
- remove excessive analysis density
- keep one clear CTA

### Backend tasks

- refactor `generate-financial-diagnosis` output for setup use
- ensure deterministic output
- ensure current snapshot includes:
  - avg monthly income
  - avg monthly spending
  - avg monthly savings
  - six-month trend data
  - one summary insight

## 6.5 Step E: Choose Plan

### Purpose

Let the user choose a believable path.

### Plans

- `Steady`
- `Recommended`
- `Accelerate`

### Core rule

Plans must be **relative to the user’s current reality**, not template-based.

That means:

- start from current savings rate
- assess income, spend, fixed costs, flexible costs, current net worth
- generate believable jumps

### Card layout

Collapsed card:

- one-line positioning copy
- savings target
- estimated FIRE date / age
- one tradeoff hint

Expanded card:

- savings target
- estimated FIRE date / age
- monthly spending ceiling
- tradeoff note

No dedicated separate page required in v1.

### Recommended positioning copy

- `Steady` — `Closest to how you live today.`
- `Recommended` — `A realistic step that moves FIRE meaningfully closer.`
- `Accelerate` — `The fastest path, with real tradeoffs.`

### Frontend tasks

- replace heavy plan-selection UI with cleaner expandable cards
- inline expand on tap
- allow `Use this plan`
- clearly show active / selected state

### Backend tasks

- rewrite `generate-plans` around official FIRE outputs, not just savings-rate projections
- include:
  - savings target
  - spending ceiling
  - official FIRE age/date estimate
  - feasibility
  - tradeoff note
  - baseline comparison

## 6.6 Step F: Apply Plan

### Purpose

Convert the chosen path into the official execution model.

### What becomes official

- active plan type
- official savings target
- official monthly spending ceiling
- official budget structure
- official Hero inputs

### Frontend tasks

- add plan application state
- return to Home on success
- update Home from active-plan data, not from temporary chooser state

### Backend tasks

- create or refactor persistence for active plan
- ensure one official active plan per user
- write setup completion state

---

## 7. Cash Flow Rebuild Spec

### Product role

Cash Flow is the **execution tab**.

It answers:

**Am I actually living the plan?**

### What stays

- all key analysis capability stays
- trend views stay
- account views stay
- category drill-down stays
- transaction drill-down stays

### What changes

- hierarchy becomes clearer
- homepage becomes lighter
- depth is capped at 3 layers

### New hierarchy

#### Level 1

- `Income`
- `Budget`
- `Savings`

#### Level 2

- module-level analysis

#### Level 3

- category detail
- account detail
- transaction grouping detail

### Explicit rule

No new fourth layer should be introduced.

### Level 1 card specs

#### Income card

Show:

- this month income
- short status line
- tap to detail

#### Budget card

Show:

- actual vs plan this month
- simple needs / wants summary
- tap to detail

#### Savings card

Show:

- actual saved vs target
- short status line
- tap to detail

### Frontend tasks

- refactor `CashflowView.swift` first screen to 3 primary modules
- move trend-heavy content into second level
- remove unnecessary routing depth
- preserve existing detail builders and drill-downs where possible
- normalize navigation patterns so sheets and full-screen covers do not create accidental fourth layers

### Backend tasks

- likely small contract updates only
- ensure budget execution APIs can return:
  - actual vs target
  - monthly savings progress
  - broad structure
- category detail endpoints may stay as-is if current performance is acceptable

---

## 8. Investment Spec

### Product role

Investment remains the **asset analysis tab**.

It answers:

**What is my portfolio doing, and how is that affecting my path?**

### Decision

This round does **not** fully redesign Investment information architecture.

### Keep

- portfolio history
- allocation
- holdings
- multi-account views
- account trends

### Change

- align visual language with new Home system
- align copy and entry points with the new Hero / strip / simulator model
- make it clearer that Investment explains one part of official FIRE progress

### Frontend tasks

- keep `InvestmentView.swift` structure mostly intact
- update copy and linking from Home
- make sure the `Invest` strip item lands in the right place
- ensure empty / syncing / loading states feel consistent with the rebuilt Home flow

### Backend tasks

- mostly preserve existing functions:
  - `get-investment-holdings`
  - `get-portfolio-history`
  - `get-account-balance-history`
- optionally add a lightweight official-impact summary that can be reused on Home

---

## 9. Backend / Edge Function Rebuild Plan

## 9.1 Principle

The backend should stop thinking in terms of “budget setup pages” and start thinking in terms of:

- setup state
- official plan state
- official Hero state
- sandbox preview state

## 9.2 Keep, rewrite, add

### Keep mostly as-is

- `create-link-token`
- `exchange-public-token`
- `get-plaid-accounts`
- `get-transactions`
- `get-net-worth-summary`
- `get-portfolio-history`
- `get-account-balance-history`
- `get-investment-holdings`

### Rewrite / extend

- `save-fire-goal`
- `get-active-fire-goal`
- `generate-financial-diagnosis`
- `generate-plans`
- `generate-spending-plan`
- `calculate-spending-stats`

### Add new backend concepts

- setup progress persistence
- official plan persistence
- official Hero read model
- sandbox preview contract

## 9.3 Recommended backend contract changes

### A. Goal profile

Current problem:

- current goal contracts are age-heavy

New v1 contract should center:

- `retirement_spending_monthly`
- `lifestyle_preset`
- optional future fields

Recommended stored fields:

- `retirement_spending_monthly`
- `lifestyle_preset`
- `fire_number`
- `withdrawal_rate_assumption`
- `inflation_assumption`
- `return_assumption`
- `is_active`

### B. Setup state

Need a resumable setup state.

Recommended fields:

- `setup_stage`
- `goal_completed_at`
- `accounts_reviewed_at`
- `snapshot_reviewed_at`
- `plan_selected_at`
- `active_plan_id`
- `last_incomplete_stage`

### C. Active plan

Need a single official active plan record.

Recommended fields:

- `plan_type`
- `savings_target_monthly`
- `savings_rate_target`
- `spending_ceiling_monthly`
- `fixed_budget_monthly`
- `flexible_budget_monthly`
- `official_fire_date`
- `official_fire_age`
- `is_active`
- `created_at`
- `updated_at`

### D. Official Hero read model

Do not force the Home Hero to recompute from scattered endpoints on every render.

Create a stable official read model that can return:

- current net worth
- fire number
- progress %
- official fire date
- official fire age
- delta summary
- plan label

This can be:

- a new Edge Function
- or a refactor of `get-active-fire-goal`

### E. Sandbox preview contract

Simulator should call a preview-focused endpoint or preview-capable function.

It should accept:

- current official plan inputs
- optional sandbox overrides
  - savings target
  - spending
  - return
  - inflation
  - withdrawal rate
  - optional target age

It should return:

- preview fire date
- preview fire age
- delta vs official
- graph series for current path vs adjusted path

## 9.4 Edge Function-by-function task list

### `save-fire-goal`

#### Change

- remove requirement for onboarding `target_retirement_age`
- support v1 minimum goal shape
- compute and persist a fire profile that can later feed official Hero and simulator

#### Tasks

- update request schema
- keep backward compatibility only if needed for migration
- persist lifestyle preset
- persist retirement spending
- persist computed fire number

### `get-active-fire-goal`

#### Change

- evolve from “goal lookup” into “official Hero source”

#### Tasks

- return official progress fields
- return official fire date
- return official fire age
- return active plan metadata
- return enough data to populate Hero without patching together too many other endpoints

### `calculate-spending-stats`

#### Change

- remain the source of income / fixed / flexible / savings reality
- ensure it can feed both snapshot and plan generation cleanly

#### Tasks

- verify six-month logic
- verify account-selection scoping
- include fields needed for:
  - snapshot cards
  - plan generation
  - budget execution

### `generate-financial-diagnosis`

#### Change

- shrink output for setup use
- emphasize one concise summary insight
- keep deterministic rules engine

#### Tasks

- reduce verbosity
- return structured snapshot content
- optionally support micro-insight lines per metric later

### `generate-plans`

#### Change

- stop being only a savings compression calculator
- become the official plan generator

#### Must output

- `Steady / Recommended / Accelerate`
- savings target
- spending ceiling
- official FIRE age/date estimate
- baseline comparison
- feasibility
- tradeoff note

#### Logic rules

- plans must be relative to current savings rate
- avoid unrealistic jumps
- do not treat all users as template buckets
- if even `Accelerate` is not enough, say so honestly

### `generate-spending-plan`

#### Change

- keep the math layer
- reposition it as derived budget generation from chosen plan

#### Tasks

- derive broad structure from savings target
- do not force category-level budgeting in v1 setup
- preserve fixed vs flexible breakdown for downstream use

### New recommended endpoint: `get-setup-state`

#### Purpose

- let Home and setup flow resume correctly

#### Output

- current setup stage
- whether goal exists
- whether accounts were linked
- whether accounts were reviewed
- whether snapshot was completed
- whether active plan exists

### New recommended endpoint: `apply-selected-plan`

#### Purpose

- turn a temporary chosen plan into the official active plan

#### Output

- active plan record
- updated Hero summary
- setup completion state

### New recommended endpoint: `preview-simulator`

#### Purpose

- power both demo simulator and real sandbox simulator

#### Modes

- `demo`
- `official-preview`

---

## 10. Frontend Task Breakdown

## 10.1 Home / Journey

### Files likely affected

- `View/Journey/JourneyView.swift`
- `View/Journey/FIRECountdownCard.swift`
- `View/Journey/SimulatorView.swift`
- `View/Journey/PortfolioCard.swift`
- `View/Journey/BudgetPlanCard.swift`
- `View/Journey/SavingsRateCard.swift`

### Tasks

- rebuild Home structure around Hero + supporting block + pull-down simulator
- remove portfolio card as the dominant second block on Home
- remove dashboard-like stacking logic
- add state-driven rendering paths
- implement pre-setup Guided Setup Card
- implement post-setup Action Strip
- separate official Hero data source from simulator data source
- add demo mode simulator entry for pre-setup users
- ensure simulator graph never mutates Hero without explicit apply

## 10.2 Setup flow

### Files likely affected

- `View/BudgetSetup/BudgetSetupView.swift`
- `View/BudgetSetup/BudgetSetupViewModel.swift`
- `View/BudgetSetup/BS_LoadingView.swift`
- `View/BudgetSetup/BS_DiagnosisView.swift`
- `View/BudgetSetup/BS_ChoosePathView.swift`
- `View/BudgetSetup/BS_ConfirmView.swift`
- `View/Shared/PlaidTrustBridgeView.swift`

### Tasks

- add a new minimum goal step before account flow
- reframe current `accountSelection -> diagnosis -> choosePath` flow into the new official order
- add `Connected Accounts Review`
- shrink diagnosis screen into true snapshot / reality check
- replace heavy plan choice UI with compact expandable cards
- collapse or remove standalone setup steps that are no longer part of the main promise
- add resume handling
- preserve good existing math and loading states where possible

## 10.3 Cash Flow

### Files likely affected

- `View/Cashflow/CashflowView.swift`
- `View/Cashflow/IncomeCard.swift`
- `View/Cashflow/BudgetCard.swift`
- `View/Cashflow/SavingsTargetCard.swift`
- detail views already under `View/Cashflow/`

### Tasks

- rebuild top-level Cash Flow page into 3 clearer entry cards
- keep trend and drill-down in secondary / tertiary levels
- reduce accidental fourth-level navigation
- audit sheets and covers
- align CTA language with official plan execution

## 10.4 Investment

### Files likely affected

- `View/Investment/InvestmentView.swift`
- related cards and detail views under `View/Investment/`

### Tasks

- keep core structure
- align copy, loading, syncing, and entry behavior with new Home story
- ensure the tab is clearly tied to official FIRE progress explanation

## 10.5 Shared state / services

### Files likely affected

- `Services/APIService.swift`
- `Services/APIService+BudgetSetup.swift`
- `Services/PlaidManager.swift`
- `Services/TabContentCache.swift`

### Tasks

- introduce setup-state fetching / caching
- introduce active-plan fetching / caching
- split official Hero fetch from simulator preview fetch
- add clean invalidation rules after:
  - plan apply
  - account linking
  - budget save
  - savings check-in

---

## 11. What Should Be Reused from the Current Budget Setup

### Reuse

- current spending stats foundation
- current financial diagnosis foundation
- current dynamic plan generation concept
- current spending plan math
- current confirm / save mechanics where valid

### Rewrite

- step order
- page framing
- overlong copy
- any UI that feels like a wizard for the sake of the wizard
- any logic that still assumes `target age` is required

### Collapse / remove from primary setup

- standalone `Spending Breakdown` as a full mandatory page
- standalone `Spending Plan` as a long separate setup ceremony

Their useful content should move into:

- snapshot
- plan expansion
- Cash Flow execution views

---

## 12. Risks and Design Guardrails

### Risk 1

Home becomes too ambitious and turns into another overloaded dashboard.

#### Guardrail

Keep Home focused on:

- official Hero
- one supporting block
- one sandbox pull-down experience

### Risk 2

Simulator and Hero become visually mixed.

#### Guardrail

- official Hero stays fixed
- sandbox remains visually labeled
- demo mode is explicit

### Risk 3

Plan generation becomes too rigid or too fake.

#### Guardrail

- plans must be relative to current user state
- unrealistic cases must be honestly labeled

### Risk 4

Rebuild scope explodes by trying to fully redesign Investment too.

#### Guardrail

Do not fully re-architect Investment in this round.

### Risk 5

Setup flow gets too long.

#### Guardrail

Each step should answer exactly one question:

- what do you want retirement to cost
- what accounts do you have
- what does your current reality look like
- which path do you want

---

## 13. Recommended Delivery Order

### Phase 1: Data model and backend contracts

- refactor goal shape
- add setup state
- add active plan persistence
- redesign `generate-plans`
- redesign `get-active-fire-goal`

### Phase 2: Setup flow

- build minimum goal step
- connect flow + review page
- snapshot page
- choose plan page
- apply plan

### Phase 3: Home rebuild

- Hero rewrite
- Guided Setup Card states
- Action Strip states
- official vs sandbox separation

### Phase 4: Simulator

- demo mode
- official sandbox mode
- preview graph and result card

### Phase 5: Cash Flow cleanup

- top-level simplification
- navigation depth cleanup

### Phase 6: Investment alignment

- entry and copy alignment
- syncing / empty-state alignment

---

## 14. Final CEO Recommendation

This rebuild should be treated as a **product system rewrite**, not a visual polish pass.

The win condition is not:

- prettier Home
- cooler animation
- more cards

The win condition is:

- a user immediately understands what Flamora is for
- setup feels like one coherent journey
- Hero becomes trustworthy
- simulator becomes magical without becoming misleading
- budget becomes a plan execution layer, not a separate side quest

If done correctly, Flamora stops feeling like:

- a finance app with FIRE decoration

and starts feeling like:

- a FIRE product with a real operating model

---

## 15. Implementation Checklist

### Product / UX

- [ ] Rewrite Home around official Hero + guided/setup strip + sandbox
- [ ] Add state-driven Home rendering
- [ ] Add Demo Simulator for pre-setup users
- [ ] Add resumable setup flow
- [ ] Add Connected Accounts Review
- [ ] Add shorter Snapshot / Reality Check page
- [ ] Replace plan selection with expandable `Steady / Recommended / Accelerate`
- [ ] Make chosen plan become the official execution baseline

### Frontend engineering

- [ ] Refactor `JourneyView.swift`
- [ ] Refactor `FIRECountdownCard.swift`
- [ ] Split official Hero state from simulator preview state
- [ ] Refactor `BudgetSetupViewModel.swift` around the new flow
- [ ] Rebuild `BS_ChoosePathView.swift`
- [ ] Add setup-state-aware Home rendering
- [ ] Simplify `CashflowView.swift` top-level hierarchy
- [ ] Align `InvestmentView.swift` with the new Home story

### Backend / Edge Functions

- [ ] Refactor goal payloads to remove required onboarding target age
- [ ] Add setup progress persistence
- [ ] Add active plan persistence
- [ ] Rebuild `generate-plans`
- [ ] Reframe `generate-spending-plan` as a derived plan-budget generator
- [ ] Rework `get-active-fire-goal` into official Hero source
- [ ] Add setup-state endpoint
- [ ] Add plan-apply endpoint
- [ ] Add simulator preview endpoint or preview mode

### Data / state consistency

- [ ] Ensure plan application invalidates relevant caches
- [ ] Ensure account-link completion updates Home state
- [ ] Ensure setup can resume from any incomplete stage
- [ ] Ensure demo simulator cannot be mistaken for official progress

