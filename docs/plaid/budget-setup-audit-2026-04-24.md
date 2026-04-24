# Budget Setup 审查 — 2026-04-24

Audit fixture: `docs/plaid/sandbox-balanced-household-budget-setup.json`
Depository only（investment 被 Plaid Dashboard holdings 校验拒绝，已剥离）。
Window：2025-10 → 2026-03 （6 个月）。

---

## Phase 1.1/1.2 — 后端纯数学测试 ✅

```bash
cd "Fire cursor"
deno test supabase/functions/_tests/ --allow-read
```

Result：41/41 PASS（spending-stats + plan-generation + 新 fixtures）。

新 fixtures：
- `high-earner-near-fire.json` — $15k 收入、$1.5M NW → `already_fire`
- `wants-heavy.json` — dining+shopping+subs+travel+entertainment heavy
- `big-rent-plus-travel.json` — 常规房租 vs 一次性 travel 的 outlier 分流

---

## Phase 1.3 — Sandbox 链路手算对照

下面的数字是从 fixture 直接算出的，流程走到对应步骤时请逐行对照。

### 收入（median 月）

| 月 | Payroll | 利息 | 合计 |
|---|---|---|---|
| 2025-10 | 4,200.00 | 4.68 | 4,204.68 |
| 2025-11 | 4,200.00 | 4.77 | 4,204.77 |
| 2025-12 | 4,200.00 | 4.81 | 4,204.81 |
| 2026-01 | 4,250.00 | 4.92 | 4,254.92 |
| 2026-02 | 4,250.00 | 5.04 | 4,255.04 |
| 2026-03 | 4,300.00 | 5.15 | 4,305.15 |

排序后中位 = (4,204.81 + 4,254.92) / 2 = **$4,229.87 → UI ≈ $4,230**

### 支出（median 月，已剔除 TRANSFER_OUT 到 savings/brokerage）

| 月 | 合计 |
|---|---|
| 2025-10 | 2,332.22 |
| 2025-11 | 2,423.76 |
| 2025-12 | 2,462.33 |
| 2026-01 | 2,325.53 |
| 2026-02 | 2,417.34 |
| 2026-03 | 2,388.40 |

排序后中位 = (2,388.40 + 2,417.34) / 2 = **$2,402.87 → UI ≈ $2,403**

### 储蓄（median of per-month net）

**逐月 net income − net expense**：[1872.46, 1781.01, 1742.48, 1929.39, 1837.70, 1916.75]
排序后中位 = (1837.70 + 1872.46) / 2 = **$1,855.08 → UI $1,855**

⚠️ **注意**：V3 用 `median(income_i − expense_i)`（先减后取中位），而不是 `median(income) − median(expense)`。两者在 income / expense 月份相关时会差几十刀，以每月 net 取中位更保守。

实际转账 $600~$1000/月（transfer 列）< $1855 —— V3 不追转账，而是反推 checking 结余的自然沉淀（cash-flow-based），更贴合真实储蓄能力。

### Canonical breakdown（6 个月平均）

**DB 实际分类（from SQL 核对）**：

| Canonical | 主要商家 | tx# | DB avg/mo | App UI |
|---|---|---|---|---|
| rent | Luna Apartments × 6 | 6 | 1,650.00 | **$1,650** ✓ |
| groceries | WF/TJ/Safeway（Costco 归 shopping）| 11 | 256.26 | **$256** ✓ |
| utilities | PG&E × 6（Comcast 归入）| 6+ | 128.50 + Comcast = ~144 | **$144** ✓ |
| shopping | Costco×2/Target×2/REI/Amazon×2/Uniqlo | 8 | 124.59 | **$139** |
| transportation | Shell/Chevron（gas only）| 6 | 74.98 | **$103**（合并 rideshare）|
| rideshare（wants）| Uber × 3 | 3 | 27.87 | 并入 Transportation 行 |
| dining_out | Sweetgreen + Blue Bottle | 5 | 60.02 | **$60** ✓ |
| travel | Delta（1 次，<3 obs → MAD 回退标 oneTime）| 1 | 23.15 | 未入 top |
| subscriptions | Spotify×3 + Netflix×3（iCloud 未入）| ~6 | ~16 | 未入 top |

**验证通过的边界分类**：
- Uber → `wants/rideshare`（非 needs/transportation），符合"gas = needs, rideshare = wants"设计
- Costco → `shopping`（非 groceries），会员店被当 wants 合理
- Comcast $89.99 → 看进 utilities（合并后 ~$144 ≈ PG&E median 128.50 + Comcast /6 ≈ 15）

**essentialFloor** = rent 1650 + utilities 144 + transportation 103 + medical 0 + groceries × 0.6 ≈ 1650 + 144 + 103 + 154 = **$2,051**

### Plan 推荐（target retire 55, retirement spending 5000）

- `fireNumber = 5000 × 12 / 0.04 = 1,500,000`
- `maxFeasibleSave = min(income − essentialFloor, income × 65%) = min(4230 − 2079, 2750) = min(2151, 2750) = 2,151`
  - limitReason = `essentials_floor`
- Primary plan：看 `closest_*` 或 `exact`（取决于 net worth 输入）。Sandbox 没内置净资产值，用户需在 Target 页填。

### 关键校验点（在 UI 上核对）

| UI 显示 | 期望值 |
|---|---|
| Reality · Earning | ≈ $4,230 |
| Reality · Spending | ≈ $2,403 |
| Reality · Saving | ≈ $1,827 |
| Reality · Top needs | Rent $1,650 > Groceries $296 > Utilities $148 > Transportation $103 |
| Reality · Top wants | Shopping $80 > Dining $60 > Subs $16 |
| Plan 页 · Today card | 复现 Reality 三数字 |
| Plan 页 · Target card | "Retire at 55 · Spend $5,000/mo"（点击能回 Step 4） |
| Category Limits 页 · Monthly budget | 与 Plan 页选中方案的 budget 一致 |
| Category Limits 页 · Save target | 与 Plan 页选中方案的 save 一致 |
| Category Limits 页 · Optional limits | 默认 None set；只有用户点某类并保存 limit 才写入 |
| Confirm 页 · 数字 | 与 Plan 页选中方案一致；category limits 不改变总 budget |
| 主页 Cashflow · Savings 行 | = active_plans.savings_target_monthly = Plan 页 $/mo |
| 主页 Home · Saving Rate target | 同上 |

---

## Phase 1.4 — 单位 / key 一致性审计 ✅

- `selectedPlanRate: committedSavingsRate * 100` → edge 函数 `income * (planRate / 100)` ✓
- `saveFinalBudget()` upsert body 现在走 `sanitizedCategoryBudgetsForSave()` → 全 canonical id ✓
- 主页 `CashflowView` 的 savings 源已切到 `getActiveFireGoal().savingsTargetMonthly`，不再用 `budgets.savings_budget` ✓
- `ratios.savings` 单位：`generate-spending-plan` 返回的是 percent（0–100），`apply-selected-plan` 直接透传，前端 `committedSavingsRate * 100` 匹配 ✓

---

## Phase 2 — Choose Plan 重构 ✅

`View/BudgetSetup/BS_ChoosePathView.swift` diff +88/-319：
- 移除：`customSaveCard` / `capsCard` / `BS_CapsSheet` / `customSaveDraft` / `showCapsSheet` / `sliderBounds` / `seedCustomSaveDraft`
- 新增：`targetAnchorCard`（可点击回 Step 4） / `todayAnchorCard`（3 列 Earning/Spending/Saving）
- Plan 卡片：`SAVE $X/mo` 升为 `.display` 主数字，BUDGET / RATE / RETIRE AT 降为次级三列
- Continue CTA：`loadSpendingPlan()` → `goToStep(.split)`

---

## Phase 3 — Step 5.5 Category Limits ✅

`View/BudgetSetup/BS_SplitBudgetView.swift` 新建：
- `Step.split = 5`，`Step.confirm = 6`
- 页面从强制分配 "Wants" 改为可选 `Set Category Limits`
- 默认不调用 `ensureCategoryBudgetsSeeded()`，不会把建议值自动写入 `category_budgets`
- 用户点某个 category 才能设置 / 更新 / 删除 monthly limit
- `Skip` 会清空 `categoryBudgets` 后继续；`Continue` 保留用户已设置的 limits
- Binding key 一致性：保存时继续 canonicalize 到 `rent/groceries/utilities/...` 等 canonical id

---

## Phase 4 — 主页连通 ✅

- `CashflowView` 新增 `activeSavingsTargetMonthly` + `refreshActiveSavingsTarget()`
- `BudgetCard` 新增 `savingsTarget: Double?` prop + `effectiveSavingsTarget` 回退
- `category_budgets` 写入全部 canonical id（通过 `sanitizedCategoryBudgetsForSave()`）
- 主页 `BudgetCard` row 循环走 canonical id → 自定义 budget 金额能被正确读到

---

## 工程可用性

- `xcodebuild -scheme "Flamora app" -destination "platform=iOS Simulator,name=iPhone 17 Pro" build` → `BUILD SUCCEEDED` ✓

---

## 待完成

- **Category Limits 端到端走查**：在模拟器里设置一个 category limit，完成确认后到 Supabase / Cashflow 主页确认 `category_budgets` 只包含用户设置的 key。
- **Portfolio 起点**：FIRE 计算仍沿用当前 `currentNetWorth` / 手动 net worth 输入；还没改成 investable portfolio balance。
- **主页待办和账户连接顺序**：还没实现 Investment account gate / Home todo CTA 逻辑。
- **其它两个 sandbox 场景**：deficit、near-fire 的 Plaid Dashboard sandbox user 还没配置（本轮范围外）。

## 风险记录

- iCloud $118.55 分类若误归 utilities 而非 subscriptions，essentialFloor 会偏高 ~$20。
- Delta $138.90 唯一一次：若 MAD 回退机制把它从 avg 里剔除，travel 会显示 $0（这是预期）。
- 转账到 brokerage（Oct/Nov $250，Dec–Mar $300）在 V3 里被归为 `TRANSFER_OUT` 排除，不会被算入 spend 也不会被算入 save。实际"真实攒下"= 6 个月累计转账 = 3,800，但 median(income−expense) ≈ $1,827/mo ≈ 10,962 / 6 — 差额来自于未被追踪的日常结余（checking 余额自然增长）。向用户解释："Saving"= income − expense 的 stable approximation。
