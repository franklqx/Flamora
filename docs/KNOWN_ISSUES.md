# Known Issues — Budget Plan / Home / Cashflow Wiring

记录于 2026-04-26,这一轮 budget/cashflow/home 数据连通改造之后剩下的已知 bug。

---

## 1. Home FIRE Hero card 在 budget plan 完成后没有更新

**现象**
- 用户走完 build budget plan 流程,提交 plan 之后回到 Home 主页
- "YOUR FIRE JOURNEY" hero card 没有切换到 active 模式
- 仍显示 setup 阶段的 "Finish the set up to track your progress." + 灰色 12 段条
- 没有出现新加的 DAY chip / 当前 portfolio 金额 / FIRE target / Freedom Date

**疑似原因**(未验证)
- `HomeHeroCardHost` 通过 `setupState?.setupStage == .active` 判断是否进入 active 渲染分支(见 [MainTabView.swift:739](View/MainTabView.swift:739))。
- budget plan 完成后,server 端 `setupStage` 是否真的翻到 `.active`?需要确认 `apply-selected-plan` 这个 edge function 有没有写入 setup state。
- 即便 server 翻了,`HomeHeroCardHost.loadData()` 触发依赖 `heroReloadTrigger`,后者只监听 `plaidManager.lastConnectionTime` / `hasLinkedBank` / `savingsCheckInGeneration` / `budgetSetupDismissGeneration`。budget setup dismiss 后会发 `.budgetSetupFlowDidDismiss` 通知,`HomeHeroCardHost` 已订阅 → `budgetSetupDismissGeneration += 1` → 应该重新拉数据。但实际是否拉成功要打 log 看。

**需要排查**
1. budget setup 完成后 `getSetupState()` 返回的 `setupStage` 实际值是什么。
2. `getActiveFireGoal()` 返回的字段是否齐全(`fireNumber`、`createdAt`、`officialFireDate`)。
3. `HomeHeroCardHost.loadData` 的 `nextHero` 是否非 nil。
4. 是否需要在 `applyPlan()` 成功后主动 invalidate `HomeSetupStateCache`。

---

## 2. Home Savings Rate card 数据没有连通

**现象**
- budget plan 走完后,Home 主页中段的 "SAVINGS RATE" 卡:
  - "Savings Amount $X/month" 不准
  - "44%" 等数字没有反映 plan 的 saving rate
  - 4 个圆圈月份打卡不显示 plan 后的状态

**疑似原因**(未验证)
- [HomeRoadmapContent.swift](View/Home/HomeRoadmapContent.swift) 已经改成:
  - `targetAmount` 优先取 `fireGoal.savingsTargetMonthly`
  - `targetRatePercent` 取 `budget.savingsRatio`
- 问题 1:`budget` 来自 `getMonthlyBudget(month:current)`,如果 plan 提交那一刻 server 还没写当月的 monthly_budget 行,这里就是 nil → 全部 fallback 到默认值。
- 问题 2:Plan 提交后 `HomeRoadmapContent` 是否收到 `.budgetSetupFlowDidDismiss` 通知 → `loadInitialData(force: true)`?onReceive 已经接了,但重载前后 `budget` 的值是否真的不一样要 log。
- 问题 3:`fireGoal` 是新加的 state,它的并发 `async let goal = ...` 在 `loadInitialData` 里(见 [HomeRoadmapContent.swift:316](View/Home/HomeRoadmapContent.swift:316)),首次冷启动可能赶不上 UI 渲染。

**需要排查**
1. plan 提交瞬间和提交完成后 `getMonthlyBudget(month:current)` 的返回值差异。
2. `getActiveFireGoal()` 在新 plan 提交后的返回是否包含 `savingsTargetMonthly`(注意这个字段是 v2 fields,nil 时整个逻辑失效)。
3. `HomeRoadmapContent.loadInitialData(force: true)` 之后 `savingsByYear` / `targetAmount` 实际是什么值(打 log)。

---

## 3. Build Plan re-setting 子分类时,Review Plan 的 Monthly Budget 显示 $0

**现象**
- 用户已经有 active plan
- 在 Cashflow → Edit budget → "Edit category budgets" 路径里重新调子分类金额
- 走到 BS_ConfirmView 的 "Review Plan" 步骤
- 顶部 "MONTHLY BUDGET" 显示 **$0**(应该是各子分类金额的合计或 plan 的 spend ceiling)

**疑似原因**(未验证)
- BS_ConfirmView / BS_PlanSetView 的 `monthlyBudgetValue` 计算链:
  ```
  viewModel.committedSpendCeiling
      ?? viewModel.spendingPlan?.totalSpend
      ?? viewModel.selectedPlan?.monthlyBudget
      ?? 0
  ```
  (见 [BS_PlanSetView.swift:25](View/BudgetSetup/BS_PlanSetView.swift:25))
- 在新加的 quick-edit 流程里(`beginQuickEditCategories`),我们只 preload 了 `categoryBudgets`,**没有 preload `committedSpendCeiling` / `spendingPlan` / `selectedPlan`**。
- 所以这条链上每一步都是 nil → fallback 到 0。

**修复方向**
- `beginQuickEditCategories()` / `beginQuickEditPlan()` 在跳到目标 step 之前,要把 active plan 的 ceiling、selected plan label、ratios 全部 hydrate 到 viewModel 里。
- 具体是从 `getActivePlan()`(或 `getActiveFireGoal()`)拿到:
  - `committed_spend_ceiling` → `viewModel.committedSpendCeiling`
  - `committed_savings_rate` → `viewModel.committedSavingsRate`
  - `committed_monthly_save` → `viewModel.committedMonthlySave`
  - `selected_plan` → `viewModel.committedPlanLabel` + 对应的 `BudgetPlanOption`
- 并且要确保 `viewModel.spendingPlan` 也被 populate(可能需要重新调 `generate-plans` 或从 active plan 反构造 `SpendingPlanResponse`)。

---

## 优先级建议

按用户体验影响大小:

1. **#3(Review Plan 显示 $0)** — 用户最容易撞到,直接挡住"调子分类"路径,优先修。
2. **#2(Savings Rate card)** — 主页核心信息流。
3. **#1(FIRE Hero card)** — 同样是主页可见,但目前只是显示 setup 引导(不算完全错),修复优先级稍后。

排查这三个 bug 时建议加临时 print log 跑一遍 happy path,看每一步的数据流入流出是什么样,再针对性修。
