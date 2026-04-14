# Flamora Rebuild TODO
> 生成日期：2026-04-14  
> 来源：多轮产品 + 架构讨论，覆盖 Budget Setup 重构、Cashflow 修复、初始状态设计、目标驱动预算主线

---

## 产品方向确认（不再讨论，直接执行）

- **方案 B**：Accounts-First。Plaid 连接解锁 Cash Flow 基本数据 + Investment 全部内容。Budget Setup 解锁 Budget 卡片 + Journey 精确 FIRE 路径。
- **target_retirement_age**：Goal Setup 必填字段（数学约束，无法省略）。产品层必填由 iOS 强制；后端 enforcement 分阶段落地，见下文"后端约束阶段性计划"。
- **需/Wants 保留**：作为 Budget 卡片的汇总展示层，编辑主维度改为 Categories（方案 D）。
- **三段推进**：Segment 1 立住目标驱动主线 → Segment 2 重写 Plan 生成 → Segment 3 改 Budget 卡片。

---

## 全局财务假设常量（统一前后端 + 所有页面）

**现状核查（2026-04-14）**：三处 FIRE 计算用的是三套不同数字：
- `_shared/fire-calculator.ts` L35：`ANNUAL_RETURN = 0.08`（nominal）
- `_shared/fire-math.ts` L28：默认 `0.07`（注释说 nominal or real 都行）
- `generate-plans/index.ts` L25/L27：`NOMINAL = 0.08` + `REAL = 0.055`
- 本文档 S1-1 PMT 预览：`0.07`

用户会在 Step 0 看到一套、Step 4 看到一套、Step 5 看到第三套，三页数字打架。

**统一方案**：

1. **新建 `Fire cursor/supabase/functions/_shared/fire-assumptions.ts`**：
```typescript
// Single source of truth for FIRE projection assumptions.
// Change here → all server-side functions update.
export const ASSUMPTIONS = {
  NOMINAL_ANNUAL_RETURN: 0.07,  // 股债 60/40 名义年化（降低以偏保守）
  REAL_ANNUAL_RETURN:    0.04,  // 扣通胀后的实际回报（NOMINAL - 3% 通胀）
  WITHDRAWAL_RATE:       0.04,  // Trinity Study 4% 规则
  INFLATION_RATE:        0.03,
} as const;
```

2. **改造三处**：
   - `fire-calculator.ts` L35：`const ANNUAL_RETURN = ASSUMPTIONS.REAL_ANNUAL_RETURN`（**注意：real，不是 nominal**。FIRECalculator 决定"能不能退休 / 需要多少 required contribution"，属于购买力判断，必须用 real return，否则 Step 4 / 5 系统性偏乐观）
   - `fire-math.ts` L28：默认值改为 `ASSUMPTIONS.REAL_ANNUAL_RETURN`（同样用于可行性判定）
   - `generate-plans/index.ts` L25/L27：`NOMINAL` 和 `REAL` 都从 `ASSUMPTIONS` 导入；可行性相关计算（rate / required contribution）用 REAL，展示性的"projected net worth in year X"用 NOMINAL

3. **iOS 端对齐**：新建 `Models/FIREAssumptions.swift`：
```swift
enum FIREAssumptions {
    static let nominalAnnualReturn: Double = 0.07
    static let realAnnualReturn: Double    = 0.04
    static let withdrawalRate: Double      = 0.04
    static let inflationRate: Double       = 0.03
}
```

4. **S1-1 PMT 预览公式**里的 `let annualReturn = 0.07` 改为 `FIREAssumptions.realAnnualReturn`（预览算的也是"达标可行性"，必须和 FIRECalculator 一致用 real）。

5. **Nominal vs Real 的使用约定**：
   - **FIRE number** (`retirement_spending × 12 / withdrawal_rate`)：用**今日购买力**计算 → 后续投影也应该用 **real return** 才能保持购买力一致
   - **但**：如果展示给用户的是"未来的金额"（例如"你 55 岁时净资产会有 $2.3M"），必须用 nominal
   - **统一规则**：所有"用来判断能不能退休"的计算用 **real return (0.04)**；所有"展示未来绝对金额"的计算用 **nominal return (0.07)**。在代码里注释清楚每处用的是哪一个。

**验收**：grep 整个代码库没有任何 hardcode 的 `0.05` / `0.055` / `0.07` / `0.08` 作为 return rate，全部引用 `ASSUMPTIONS` / `FIREAssumptions`。

---

## 数据依赖关系（决定解锁时机）

| 功能 | 需要 Plaid | 需要 Budget Setup |
|------|:---:|:---:|
| Cash Flow：Income / 支出 / 交易 | ✅ | — |
| Cash Flow：Budget 卡片 | ✅ | ✅ |
| Cash Flow：Savings 卡片 | ✅ | ✅ |
| Investment：全部内容 | ✅ | — |
| Journey：FIRE Number（粗估，onboarding 自报数据）| — | — |
| Journey：FIRE Number（精确，Plaid net worth）| ✅ | — |
| Journey：精确 FIRE 倒计时 / 达标路径 | ✅ + Goal | — |
| Journey：Budget Plan 进度 | ✅ | ✅ |

**关于"粗估 FIRE Number"的一致性说明**：粗估 FIRE number = `retirement_spending_monthly × 12 / 0.04`，只依赖用户在 onboarding 输入的月退休花费，不依赖 Plaid。下面页面状态设计里说"未连 Plaid 时 FIRE Number 显示无数据"是**错误表述**，已在"各 Tab 页面状态设计"里修正为：未连 Plaid 且已完成 onboarding 的用户，FIRE Number 粗估可算出来；完全空用户（未填退休花费）才显示 `--`。

---

## 各 Tab 页面状态设计（已确认）

### 未连接 Plaid

**Cash Flow Tab**
- 顶部深蓝区域：日历 + Trend 正常渲染，日历内无 transaction 数据，Trend 无数据曲线（空状态 UI）
- Budget 卡片：锁定状态，CTA 引导到 Budget Setup
- Savings 卡片：锁定状态

**Investment Tab**
- Portfolio UI 卡片 + CTA（按现有设计保持不变）

**Journey Tab**
- FIRE Number 区域：
  - 用户已在 onboarding 填写 `retirement_spending_monthly` → 显示粗估 FIRE number（`月退休花费 × 12 / 0.04`），配副标题 "Estimated — connect your accounts for exact tracking"
  - 未填退休花费的彻底空用户 → 显示 `--` 占位
- FIRE 倒计时 / 达标路径：无数据空状态（这部分需要 Plaid）
- 下方 Todo list：引导用户完成连接账户 + 设置目标的步骤

### 已连接 Plaid，未完成 Budget Setup

**Cash Flow Tab**
- Income / 支出 / 交易：✅ 显示真实数据
- Budget 卡片：显示 "Set Up Your Budget" CTA（功能引导，非锁定）
- Savings 卡片：显示实际储蓄额，无 target

**Investment Tab**
- ✅ 全部正常显示，与 Budget Setup 状态无关

**Journey Tab**
- ✅ 使用真实 Plaid net worth 更新 FIRE 倒计时
- Budget Plan 进度卡片：CTA "Complete budget setup"

### 已连接 Plaid + 已完成 Budget Setup

所有内容正常显示。

---

## SEGMENT 0：Bug 修复（最优先，不阻塞其他 Segment）

### S0-1：修复 cashflow_edit ratio bug【必须最先修】

**文件**：`View/Cashflow/CashflowView.swift`  
**位置**：`saveBudgetEdit()` L394–397  
**问题**：needs_ratio + wants_ratio 归一到 100（不含 savings），然后 savings_ratio 单独追加，导致三者之和约 120，后端 INVALID_RATIOS 400 报错，cashflow edit 静默失败。

**修法**：删除现有归一逻辑，改为从绝对金额重算三个 ratio：

```swift
// 删掉：
// requestPayload["needs_ratio"] = payload.needsRatio / ratioSum * 100
// requestPayload["wants_ratio"] = payload.wantsRatio / ratioSum * 100

// 改为：
let needsBudget   = payload.needsBudget
let wantsBudget   = payload.wantsBudget
let savingsBudget = apiBudget.savingsBudget
let totalBudget   = needsBudget + wantsBudget + savingsBudget
if totalBudget > 0 {
    requestPayload["needs_ratio"]   = needsBudget   / totalBudget * 100
    requestPayload["wants_ratio"]   = wantsBudget   / totalBudget * 100
    requestPayload["savings_ratio"] = savingsBudget / totalBudget * 100
}
```

**验证**：三值之和 = 100，后端 hasCustomRatios 分支通过校验。

---

### S0-2：修复 category_budgets 存取链路断裂

**问题**：iOS 传 `category_budgets` 到两个地方（CashflowView L390、BudgetSetupViewModel L588），但后端两端都断了：写入时丢弃，读取时不返回，`APIMonthlyBudget.categoryBudgets` 永远是 nil。

**前置确认（已核查 2026-04-14）**：`budgets` 表**当前没有** `category_budgets` 列 —— 在 `Fire cursor/supabase/migrations/` 三个 migration 文件里未出现该字段，`generate-monthly-budget/index.ts` 的 upsert payload 也没有写入。因此 S0-2 必须以新建 migration 作为第一步。

**后端改动 0（新增 migration，必须先做）**：新建 `Fire cursor/supabase/migrations/20260414_add_category_budgets.sql`：
```sql
ALTER TABLE budgets
  ADD COLUMN IF NOT EXISTS category_budgets JSONB DEFAULT '{}'::jsonb;

COMMENT ON COLUMN budgets.category_budgets IS
  'Per-category budget amounts, keyed by TransactionCategoryCatalog.id (canonical stable id, NOT display name). Shape: { "groceries": 450, "dining_out": 200, ... }';
```
部署：`supabase db push` 或走现有 migration 流程。验证：`select column_name from information_schema.columns where table_name='budgets' and column_name='category_budgets';` 返回一行。

---

#### S0-2a：统一 iOS 侧 category_budgets 的 key 规范（必做，否则读写不匹配）

**当前代码状况**（已核查）：
- **写入端**：`BudgetCard.saveEditedBudget()` L811–814 用 `item.name`（展示名，如 `"Dining Out"`）当 key
- **写入端**：`BudgetSetupViewModel.categoryBudgets` L131、L588 的 key 来源同样是展示名
- **读取端**：`CashflowView.budgetCategories()` L291–298 用 `budgetMap.keys`，经过 `TransactionCategoryCatalog.parent(for:)` —— 该函数对 id 和 name 都能解析（见 `Models/TransactionCategoryCatalog.swift` L99），所以现状没崩，是**靠容错掩盖了不一致**

**为什么必须改成 id**：展示名会因为 i18n / rename 变化，数据库里的 JSONB 应该用稳定 id。

**iOS 改动**：

1. `Models/TransactionCategoryCatalog.swift`：新增工具方法
```swift
static func id(forDisplayedSubcategory name: String) -> String? {
    all.first(where: { $0.name == name })?.id
}
```

2. `View/Cashflow/BudgetCard.swift` L811–814：写入时用 id
```swift
let categoryMap = (draftNeedsCategories + draftWantsCategories)
    .reduce(into: [String: Double]()) { partialResult, item in
        let key = TransactionCategoryCatalog.id(forDisplayedSubcategory: item.name) ?? item.name
        partialResult[key] = max(item.amount, 0)
    }
```

3. `View/BudgetSetup/BudgetSetupViewModel.swift` L131 附近：在组装 `categoryBudgets` 的所有写入点用 id（具体行需看 S3-2 重构时的 category 编辑器实现）

4. `View/Cashflow/CashflowView.swift` L291：读取逻辑明确以 id 为主路径
```swift
let budgetMap = apiBudget.categoryBudgets ?? [:]
// budgetMap 的 key 现在保证是 canonical id
// TransactionCategoryCatalog.parent(for:) 仍保留作为兜底（处理老数据）
```

**读路径标准化规则（必做，避免 id / 展示名并存）**：在 `budgetCategories(from:parent:)` 里，`budgetMap.keys` 是 canonical id，而 `defaultNames` / `spendingNamesForParent` 是展示名 —— 如果直接塞进同一个 `orderedNames`，会出现 `"groceries"` 和 `"Groceries"` 同时入列，导致金额匹配漂移、排序重复。实施时统一规则：

- 合并前，先把 `budgetMap.keys`（id）通过 `TransactionCategoryCatalog.all.first(where: { $0.id == key })?.name` 映射成展示名，得到 `budgetDisplayNamesForParent: [String]`；无法解析的老数据 key（rename 前的遗留）保留原值作为兜底。
- `orderedNames` 合并顺序保持不变，但三路来源**都必须是展示名**：`budgetDisplayNamesForParent` → `defaultNames` → `spendingNamesForParent`。
- `spendingByName` / 金额查找 / 填充保持以展示名为 key；需要回查 budget 金额时，用 `TransactionCategoryCatalog.id(forDisplayedSubcategory:)` 现场把展示名换成 id 再去 `budgetMap` 取值。
- **禁止**在 `orderedNames` 里混用 id 和展示名。

5. `BudgetCard` 渲染 per-category 预算额时，需要从 id 反查展示名：用现有 `TransactionCategoryCatalog.all.first(where: { $0.id == key })?.name`。

**数据迁移**：老用户的 `category_budgets` 已经是空的（因为后端之前丢弃写入），所以**不需要**数据 backfill。新数据从切换那一刻开始全部用 id。

**验收**：
- [ ] 保存 budget → Supabase `budgets.category_budgets` JSON 里的 key 全部是 `TransactionCategoryCatalog.all` 中的 `id`
- [ ] 重新打开 Cash Flow → `BudgetCard` 正确显示用户设定的金额
- [ ] 改了 `TransactionCategoryCatalog` 里某个 category 的 `name`（模拟 rename）→ 用户之前设的预算仍然正确对上

**存储语义统一规则**（定死，避免读写不一致）：`budgets.category_budgets` 列**统一用空对象 `{}` 表达"无数据"**，不使用 `NULL`。写入时若 body 没带 `category_budgets`，存 `{}`；读取时若列意外为 `NULL`（老数据），兜底返回 `{}`。iOS 端 `APIMonthlyBudget.categoryBudgets` 解码拿到的恒为字典（可能为空），不需要判 nil。

**后端改动 1**：`Fire cursor/supabase/functions/generate-monthly-budget/index.ts`
在 upsert payload（L228–246）里加一行：
```typescript
category_budgets: body.category_budgets ?? {},
```

**后端改动 2**：`Fire cursor/supabase/functions/get-monthly-budget/index.ts`
在 response body（L110–138）里加：
```typescript
category_budgets: budget.category_budgets ?? {},
```

（可选）migration 里把 `category_budgets JSONB` 列的 `DEFAULT` 设为 `'{}'::jsonb`，从 schema 层面兜住"写入未带字段"的情况。

**iOS 无需改**：`APIMonthlyBudget.categoryBudgets` 字段已存在，解码会自动拾取。

---

## SEGMENT 1：目标驱动主线（核心，立住后再动其他）

> 目标：让产品逻辑第一次真正"由目标驱动"。Step 4 展示 required vs current savings gap，用户知道自己离目标差多少再去选 Plan。

### S1-1：BS_GoalSetupView 新增 target_retirement_age 必填字段

**文件**：`View/BudgetSetup/BS_GoalSetupView.swift`

**改动**：
- 在退休花费输入卡片下方新增 "Target Retirement Age" 输入行（数字输入，整数，范围 currentAge+5 至 75）
- 实时预览区域新增一行：基于 age gap 和当前粗估 net worth，给出"大概每月需要存 $X"（客户端用简单 PMT 估算，仅作即时反馈，不调 API）
- CTA "Continue" 的 disabled 条件改为：`retirementSpendingMonthly <= 0 || targetRetirementAge <= 0`

**即时预览的 PMT 估算公式**（客户端纯数学，不依赖后端）：

```swift
// 输入
let currentAge: Int             // OnboardingData.age
let targetAge: Int              // 用户刚输入
let retirementSpending: Double  // 月退休花费（用户刚输入）
let currentNetWorth: Double     // 粗估，无 Plaid 时传 0
let annualReturn = FIREAssumptions.realAnnualReturn  // 0.04，可行性判定用 real
let withdrawalRate = FIREAssumptions.withdrawalRate  // 0.04，4% 规则

// 计算
let fireNumber = retirementSpending * 12 / withdrawalRate   // 目标净资产
let years = max(1, targetAge - currentAge)
let months = years * 12
let monthlyRate = annualReturn / 12

// 当前净资产的未来价值（复利增长）
let fvCurrent = currentNetWorth * pow(1 + monthlyRate, Double(months))

// 还差多少
let gap = max(0, fireNumber - fvCurrent)

// PMT 公式：每月定投多少才能在 months 个月后凑出 gap
// pmt = gap * r / ((1+r)^n - 1)
let requiredMonthly: Double = {
    if monthlyRate == 0 { return gap / Double(months) }
    let factor = pow(1 + monthlyRate, Double(months)) - 1
    return gap * monthlyRate / factor
}()
```

**UI 文案**（展示 `requiredMonthly`）：
- `requiredMonthly <= 0`：`"You've already hit your goal 🎉"`
- `requiredMonthly > 0`：`"Roughly $X/mo to get there"`

**注意**：Step 0（Goal Setup）在当前流程里**早于** Plaid 连接和 `calculate-spending-stats` 调用，`BudgetSetupViewModel.spendingStats` 此时为 nil，所以**不能**在 Step 0 做 "≤60% income" 的可行性分层文案。用户 onboarding 自报的收入也不可靠（很多人只在 Plaid 后才有真实值）。简化为只显示金额，可行性判定留给 Step 4 `calculate-fire-goal`。

Step 4 的 Diagnosis 卡片（S1-3）才是做可行性分层的正确位置，那里 `spendingStats` 和 `goalFeasibility` 都已 ready。

**ViewModel 改动**：`View/BudgetSetup/BudgetSetupViewModel.swift`
- 新增 `var targetRetirementAge: Int = 0`
- `saveFireGoal()` 里把 `targetRetirementAge` 传给 `SaveFireGoalRequest`

**Model 改动**：`Models/BudgetSetupModels.swift`  
- `SaveFireGoalRequest` 新增 `targetRetirementAge: Int`（对应后端已支持的 `target_retirement_age`，本轮无需改后端）

**后端约束阶段性计划**（必须写进 roadmap，否则新主线实质上不闭环）：

| 阶段 | 动作 | 触发时机 |
|------|------|---------|
| **本轮（P0）** | 后端保持 `target_retirement_age` optional；iOS 强制必填；老用户兜底见 S1-1a | 本轮上线 |
| **P1（本轮上线后 1 个迭代内）** | `save-fire-goal` 增加 runtime 校验：若 request 缺 `target_retirement_age` 且 `selected_plan` 属于新主线（steady/recommended/accelerate）→ 返回 400 `MISSING_RETIREMENT_AGE`；老枚举值（current/plan_a/plan_b）仍可通过 | 新 iOS 版本覆盖率 ≥ 95% 后 |
| **P2（彻底切换）** | DB 加约束：`ALTER TABLE fire_goals ADD CONSTRAINT target_age_required CHECK (target_retirement_age IS NOT NULL)` + `save-fire-goal` 直接拒绝；或新建 `save-fire-goal-v2` endpoint 强制要求 | 旧客户端彻底下线后 |

**为什么分阶段**：直接在 DB 加 NOT NULL 约束会让线上旧客户端和正在途的老 goal 记录全部失败。先在应用层逐步收紧，再加 DB 约束。

---

#### S1-1a：老用户 / 中途退出的恢复流程（必做）

**问题**：把 `target_retirement_age` 升为必填后，下列三类用户会在 Step 4 调 `calculate-fire-goal` 时直接失败（返回 400 或 feasibility 全空）：
1. **老用户**：之前 onboarding 没填过 target_retirement_age，`fire_goals.target_retirement_age IS NULL`
2. **中途退出**：用户 Step 2 填完 goal 退出 app，重新打开时 ViewModel 内存丢失
3. **多设备**：用户在 device A 走到 Step 3，在 device B 打开 Budget Setup

**现状核查**：当前恢复主要靠 `get-setup-state`，**没有**从 `fire_goals` 回填 `targetRetirementAge` / `retirementSpendingMonthly` 的逻辑。

**改动 1（必做）**：`BudgetSetupViewModel.loadInitialData()` 里新增"从 active fire goal 回填"：

```swift
func loadInitialData() async {
    // ...现有 loadSetupState / loadSpendingStats 等

    // 新增：从 active fire goal 回填 ViewModel 状态
    await restoreFromActiveFireGoal()

    // ...继续 loadDiagnosis / loadGoalFeasibility
}

private func restoreFromActiveFireGoal() async {
    do {
        // APIService.getActiveFireGoal() 已存在（APIService.swift:207），返回 APIFireGoal (mockdata.swift:760)
        let goal: APIFireGoal = try await APIService.shared.getActiveFireGoal()
        if let spending = goal.retirementSpendingMonthly, spending > 0 {
            retirementSpendingMonthly = spending
        }
        if let age = goal.targetRetirementAge, age > 0 {
            targetRetirementAge = age
        }
    } catch {
        print("⚠️ [BudgetSetup] no active fire goal to restore: \(error)")
    }
}
```

**类型复用**：使用仓库里**已有的** `APIFireGoal`（`Models/mockdata.swift:760`，已包含 `targetRetirementAge: Int?` 和 `retirementSpendingMonthly: Double?`）和**已有的** `APIService.getActiveFireGoal()`（`Services/APIService.swift:207`）。不要再新建 `ActiveFireGoalResponse` 类型、也不要在 `APIService+BudgetSetup.swift` 里重复声明 `getActiveFireGoal` —— 本段只需要调用现成 API。

**改动 2（必做）**：`get-active-fire-goal/index.ts` 确认返回 `target_retirement_age` 和 `retirement_spending_monthly`（如已返回则跳过）。需查源码确认。

**改动 3（老用户兜底）**：对于 `fire_goals.target_retirement_age IS NULL` 的老用户，Step 4 的流程应该：
- 如果 ViewModel 读出来 `targetRetirementAge == 0` → **强制把流程回滚到 S1-1 的 Goal Setup 页面**（插入一个 "We need one more detail" 拦截屏），用户填完 age 再继续
- 不允许 Step 4 在 `targetRetirementAge == 0` 的状态下调 `calculate-fire-goal`

**改动 4（Journey Tab）**：Journey Tab 的 FIRE 倒计时 / 达标路径，如果读到的 active goal 没有 `target_retirement_age`，显示 "Complete your goal setup" CTA 而不是报错。

**验收**：
- [ ] 新建账号走完 onboarding 再杀进 Budget Setup → `targetRetirementAge` 从 DB 回填正确
- [ ] `fire_goals` 手动把 `target_retirement_age` 设为 NULL（模拟老用户）→ Step 4 不崩，拦截到 Goal Setup 补填
- [ ] Step 2 填完 goal 后杀 app → 重开进入 Budget Setup → Step 4 的 feasibility 能正常算出来

---

### S1-2：BudgetSetupViewModel 新增 Goal Feasibility 状态

**文件**：`View/BudgetSetup/BudgetSetupViewModel.swift`

**新增状态**：
```swift
var goalFeasibility: GoalFeasibilityResult? = nil
var isLoadingFeasibility = false
```

**新增 Model**（`Models/BudgetSetupModels.swift` 或新建 `Models/GoalFeasibilityModel.swift`）：
```swift
struct GoalFeasibilityResult: Codable {
    let phase: Int                          // 0 / 1 / 2
    let phaseSub: String                    // "0a","0b","0c","0d","1","2"
    let strategy: String                    // "goal_achievable" | "user_choice" | "impossible"
    let fireNumber: Double
    let gapToFire: Double
    let requiredMonthlyContribution: Double // 每月必须存多少
    let requiredSavingsRate: Double         // 对应储蓄率 %
    let yearsToRetirement: Int
    let isAchievable: Bool
    let currentPath: FeasibilityPath
    let planA: FeasibilityPath?             // 保持目标年龄，增加储蓄
    let planB: FeasibilityPath?             // 保持现有储蓄率，推迟退休
    let recommended: FeasibilityPath?       // 平衡路径
}

struct FeasibilityPath: Codable {
    let retirementAge: Int
    let savingsRate: Double
    let monthlySavings: Double
    let feasibility: String // "comfortable" | "balanced" | "aggressive" | "unrealistic"
}
```

**新增函数**：`loadGoalFeasibility()` 在 `loadInitialData()` 完成后调用：
```swift
func loadGoalFeasibility() async {
    guard targetRetirementAge > 0,
          retirementSpendingMonthly > 0,
          let stats = spendingStats else { return }

    isLoadingFeasibility = true
    do {
        // 用 Plaid 实际数据 override，比 user_profiles 里的自报数据更准
        goalFeasibility = try await APIService.shared.calculateFireGoal(
            targetRetirementAge: targetRetirementAge,
            monthlyIncome: stats.avgMonthlyIncome,
            currentMonthlyExpenses: stats.avgMonthlyExpenses,
            desiredMonthlyExpenses: retirementSpendingMonthly,
            currentNetWorth: currentNetWorth > 0 ? currentNetWorth : nil,
            currentAge: currentAge > 0 ? currentAge : nil
        )
    } catch {
        print("❌ [BudgetSetup] loadGoalFeasibility error: \(error)")
    }
    isLoadingFeasibility = false
}
```

**调用时机**：在 `loadInitialData()` 的 `loadDiagnosis()` 完成后紧接调用。

**APIService 新增 typed 方法**：`Services/APIService+BudgetSetup.swift`

ViewModel 里不应该手拼 JSON body 和 `authenticatedRequest`。所有新接入的 edge function 都加 typed wrapper：

```swift
extension APIService {
    func calculateFireGoal(
        targetRetirementAge: Int,
        monthlyIncome: Double,
        currentMonthlyExpenses: Double,
        desiredMonthlyExpenses: Double,
        currentNetWorth: Double?,
        currentAge: Int?
    ) async throws -> GoalFeasibilityResult {
        var body: [String: Any] = [
            "target_retirement_age": targetRetirementAge,
            "monthly_income": monthlyIncome,
            "current_monthly_expenses": currentMonthlyExpenses,
            "desired_monthly_expenses": desiredMonthlyExpenses,
        ]
        if let nw = currentNetWorth, nw > 0 { body["current_net_worth"] = nw }
        if let age = currentAge, age > 0 { body["current_age"] = age }
        let data = try JSONSerialization.data(withJSONObject: body)
        let request = try await authenticatedRequest(function: "calculate-fire-goal", body: data)
        return try await perform(request)
    }

    // 注意：getActiveFireGoal() 已在 APIService.swift:207 存在，返回 APIFireGoal。
    // 不要在这里重复声明。直接用 APIService.shared.getActiveFireGoal()。

    // 注意：`generatePlans(data: GeneratePlansRequest)` 已存在于本文件（见现有实现）。
    // 不要再新增同名但不同参数的重载 —— 语义会混乱。
    // 本轮做法：**扩展现有 `GeneratePlansRequest` 结构体**，新增可选字段
    // （`targetRetirementAge`, `accountIds`, `month`），以及把 `retirementSpendingMonthly`
    // 保持可选，仍然透传完整 spendingStats。调用点继续使用已有的
    // `APIService.shared.generatePlans(data: request)`。
    //
    // 对应 Models/BudgetSetupModels.swift 的 GeneratePlansRequest 扩展：
    //   var targetRetirementAge: Int? = nil       // "target_retirement_age"
    //   var accountIds: [String]? = nil           // "account_ids"
    //   var month: String? = nil                  // "month"
    // （其余字段 currentSavingsRate / avgMonthlyIncome / avgMonthlySavings /
    //  avgMonthlyFixed / avgMonthlyFlexible / currentNetWorth / currentAge 保持不变，
    //  服务端直接使用，不再自己重算 stats。）
    //
    // 迁移说明：`PlansResponse` 类型名保持不变，本轮不改。
}
```

ViewModel 里只调 `try await APIService.shared.calculateFireGoal(...)`，不再手拼 body。

---

### S1-3：BS_DiagnosisView 新增 Goal Feasibility 区块

**文件**：`View/BudgetSetup/BS_DiagnosisView.swift`

**新增区块**（在 AI Insights 下方）：Goal Progress Card，展示：

```
YOUR GOAL GAP
─────────────────────────────────────
Current monthly savings:   $1,200  (18%)
Required to hit goal:      $2,400  (36%)
Gap:                      +$1,200/mo

Feasibility: ACHIEVABLE WITH EFFORT
"At this rate, you'd retire at 67. 
 To retire at 55, you need to save 
 an extra $1,200 each month."
─────────────────────────────────────
```

**四种可行性状态对应的 UI 文案**（来自 `phase` + `feasibility`）：

| phase / feasibility | 标签颜色 | 核心文案 |
|---------------------|---------|---------|
| Phase 0a（已达到 FIRE） | 绿 | "You've already hit your FIRE number." |
| Phase 0b/0c（on track） | 绿 | "You're on track to retire at [age]." |
| Phase 0d / Phase 1, comfortable/balanced | 黄 | "Achievable — you need $X more/month." |
| Phase 1, aggressive | 橙 | "Ambitious — requires significant lifestyle change." |
| Phase 2（unrealistic） | 红 | "Goal needs adjustment — current income can't support this timeline." |

**加载状态**：独立 loading indicator，不阻塞 Diagnosis 其他卡片的显示。

---

### S1-4：Budget Setup 流程中的账户连接与账户选择分离

**背景**：当前 BudgetSetupViewModel Step 1（accountSelection）包含 Plaid 连接动作。按方案 B，Plaid 连接是 app 级别的 onboarding 动作，Budget Setup 里只需确认"哪些已连账户参与分析"。

**改动**：`View/BudgetSetup/BS_AccountSelectionView.swift`
- 如果用户已连接 Plaid（`plaidManager.hasLinkedBank == true`）：直接显示已连账户列表供选择，无需再触发 Link flow
- 如果未连接：显示"First, connect your accounts"引导，触发 Plaid Link，完成后自动进入账户选择

**`BudgetSetupViewModel`**：
- `Step.accountSelection` 语义从"连接账户"改为"选择参与分析的账户"
- Plaid Link 触发逻辑保留作为"未连接时的 fallback"，不是主路径

---

### S1-5：初始状态页面实现

**Cash Flow Tab**：`View/Cashflow/CashflowView.swift`

当前：`plaidManager.hasLinkedBank` 控制全部内容。
改为分层控制：
```swift
// Income / Transaction / Trend：只看 hasLinkedBank
// Budget 卡片：hasLinkedBank && budgetSetupCompleted
// Savings 卡片：hasLinkedBank && budgetSetupCompleted
```

顶部深蓝区域（日历 + Trend）：未连接时渲染空状态 UI（日历格无数据，Trend 无曲线），不隐藏控件本身。

**Journey Tab**：`View/Journey/JourneyView.swift` + `JourneyViewModel.swift`

- FIRE Number 区域：无数据时显示 `--` 占位，不显示 $0
- Todo list 组件：新增，根据用户完成状态动态显示引导项：
  - [ ] Connect your accounts
  - [ ] Set your FIRE goal
  - [ ] Complete budget setup

**Todo list 组件 UI 规格**：

新建文件 `View/Journey/JourneyTodoList.swift`，样式规范：

```
┌────────────────────────────────────────┐
│  GET STARTED                           │  ← .cardHeader (11, bold, uppercase)
│                                        │
│  ◯  Connect your accounts        →    │  ← 未完成：空心圆 + chevron
│     Link your bank to see real data    │    标题 .bodySemibold / 副 .footnoteRegular
│  ────────────────────────────────────  │    divider: AppColors.overlayWhiteForegroundSoft
│  ◯  Set your FIRE goal           →    │
│     Tell us when you want to retire    │
│  ────────────────────────────────────  │
│  ◯  Complete budget setup        →    │
│     Get a personalized savings plan    │
└────────────────────────────────────────┘
  卡片底色：AppColors.cardBackground
  padding：AppSpacing.cardPadding
  圆角：AppRadius.card
  item 间距：AppSpacing.md
```

**状态规则**：
| Item | 完成条件 | 完成态样式 |
|------|---------|-----------|
| Connect your accounts | `plaidManager.hasLinkedBank` | ✓ 实心圆（fire gradient 填充）+ 标题删除线灰色 |
| Set your FIRE goal | `JourneyViewModel.hasFireGoal`（从 get-active-fire-goal 拿到非空结果）| 同上 |
| Complete budget setup | `JourneyViewModel.budgetSetupCompleted`（从 get-setup-state 拿到）| 同上 |

**点击跳转**：
- "Connect your accounts" → 调 `plaidManager.startLinkFlow()`（直接拉起 Plaid Link sheet，与 Cash Flow CTA 行为一致）
- "Set your FIRE goal" → 跳转到 Budget Setup 流程第 0 步（NavigationLink push，或通过现有的 Budget Setup 入口触发）
- "Complete budget setup" → 跳转到 Budget Setup 流程当前未完成的步骤（复用 `BudgetSetupViewModel.currentStep`）

**显示逻辑**：
- 三项全部完成 → 整个 Todo list 卡片隐藏
- 完成态的 item 保留在列表中显示（给用户"已完成"的满足感），但不响应点击
- 未连 Plaid 且未设目标时，三项按顺序显示；已完成项置底

**Investment Tab**：按现有设计保持不变。

---

## SEGMENT 2：Plan 生成逻辑改为目标驱动

> 前置条件：S1 全部完成，goalFeasibility 数据稳定可用。

### S2-1：改写 generate-plans 后端逻辑

**文件**：`Fire cursor/supabase/functions/generate-plans/index.ts`

**核心改动**：当 `calculate-fire-goal` 的结果可用时，三个 Plan 的 rate 来自 FIRECalculator 路径，不再使用 flexible 压缩比（10%/25%/40%）。

**映射关系**（来自 `FIRECalculator.adjustGoal()` 输出）：

| UI Plan | FIRECalculator 路径 | 语义 |
|---------|---------------------|------|
| Steady | `plan_b` | 维持现有储蓄率，退休年龄自然延后 |
| Recommended | `recommended` | 平衡路径（储蓄率 ≤60% 的最近平衡点） |
| Accelerate | `plan_a` | 锁定目标年龄，达到 required_savings_rate |

**边界情况处理**：

Phase 0（已 on track，`plan_b = null`，`recommended = null`）：
- Steady = `current_path`（维持现状已够）
- Recommended = `plan_a`（精确达成目标年龄）
- Accelerate = 在 `plan_a.savings_rate` 基础上再加一个 tier（提前 5 年退休需要的 rate，客户端或服务端均可计算）

Phase 1（可达但需努力）**部分子状态下 `recommended` 也会是 null**（例如 `plan_a.savings_rate > 60%` 时 FIRECalculator 找不到 ≤60% 的平衡点）：
- Steady = `plan_b`
- Recommended **fallback 链**：`recommended ?? plan_a ?? plan_b ?? current_path`，并在卡片角标显示小提示"Aggressive path — no balanced option at this timeline"
- Accelerate = `plan_a`

Phase 2（目标不可达，`plan_a.feasibility = 'unrealistic'`）：
- Steady = `plan_b ?? current_path`
- Recommended = `plan_a`（此时 plan_a 就是"能做到的最好方案"）
- Accelerate：显示 `plan_a` 但加 `"warning": true` 标记，iOS 端显示"Goal may need adjustment"警告
- UI 顶部加 feasibility banner

**通用兜底规则**：`generate-plans` 服务端在装配三张 UI 卡片前，对每张卡执行：
```typescript
const steady      = plan_b ?? current_path
const recommended = recommended ?? plan_a ?? plan_b ?? current_path
const accelerate  = plan_a ?? recommended ?? current_path
```
保证无论 FIRECalculator 返回什么组合，三张卡永远有数据，不会出现"三张卡 UI 但只有两条路径"的情况。若三张卡最终指向同一个路径（极端 Phase 0 情况），服务端可选择只返回两张卡 + 一条说明，由 iOS 适配显示。

**实现方式（修正：信任边界）**：**不接受** iOS 回传的 `feasibility_result`。原因：(1) 客户端派生结果可伪造，后端以客户端计算为真相不安全；(2) iOS 在 Step 4 拿到 feasibility 后，到 Step 5 点"Continue"之间用户可能改 target_retirement_age / retirement_spending_monthly，客户端缓存会漂移。

正确做法：`generate-plans` 自己在服务端调用 `FIRECalculator.adjustGoal()` 重算。

**入参契约**（iOS → generate-plans）：**前端透传完整 spendingStats**（与当前 `GeneratePlansRequest` 结构体一致），服务端不再自己重算 baseline。选择此路而不是"只传 account_ids 让服务端全算"的原因：Step 4 已经通过 `calculate-spending-stats(account_ids=...)` 算好 stats 并用于 feasibility，Step 5 直接复用可保证两步 baseline 完全一致（无漂移）、且减少一次 edge function 调用。

```typescript
// generate-plans request body (修订)
{
  // ▼ Step 4 已算好的 spendingStats，完整透传（对应 iOS GeneratePlansRequest 全部字段）▼
  current_savings_rate: number,             // 现有字段
  avg_monthly_income: number,               // 现有字段
  avg_monthly_savings: number,              // 现有字段
  avg_monthly_fixed: number,                // 现有字段
  avg_monthly_flexible: number,             // 现有字段
  current_net_worth: number,                // 现有字段
  current_age: number,                      // 现有字段

  // ▼ 新增可选字段 ▼
  month?: string,                           // 新增，用于 plan 月份定位
  target_retirement_age?: number,           // 可选，服务端优先用此值
  retirement_spending_monthly?: number,     // 可选，服务端优先用此值（原已有）
  account_ids?: string[],                   // 仅用于审计/日志，服务端不会再用它重算 stats

  // 不传 feasibility_result、不传 plan_a/plan_b/recommended
}
```

**服务端流程**（`generate-plans/index.ts`）：
1. 从 `fire_goals` 表读取当前 active goal（通过 `user_id` + `is_active=true`）
2. 如果 request body 里带了 `target_retirement_age` / `retirement_spending_monthly`，用 request 值 override；否则用 goal 里的值
3. **baseline 决策（硬约束）**：完整 spendingStats（`current_savings_rate` / `avg_monthly_income` / `avg_monthly_savings` / `avg_monthly_fixed` / `avg_monthly_flexible` / `current_net_worth` / `current_age`）都是 request 必填。服务端**不再**自己调 `calculate-spending-stats`。这样 Step 4 feasibility 和 Step 5 plans 天然共用同一 baseline。
4. 若 request 缺任一 stats 字段，返回 400 `STATS_MISSING`，由 iOS 负责先跑完 Step 4 再进 Step 5。
5. 服务端调用 `_shared/fire-calculator.ts` 的 `adjustGoal()` 得到 `plan_a / plan_b / recommended / current_path`
6. 按下面映射表生成三张 UI Plan 卡片

**iOS 端配合**（`BudgetSetupViewModel.loadPlans()`）：沿用现有 `GeneratePlansRequest`，在组装 request 时把 `targetRetirementAge`、`accountIds`（审计用）、`month` 填上，其余 stats 字段已经在透传，不需要改调用形状。

**注意**：`generate-plans` 内部的 `buildPlan()` 函数（计算 projections、FIRE date 等）保持不变，只替换 rate 的来源为服务端重算的 FIRECalculator 路径。

**前端漂移保护**：iOS 在 `loadPlans()` 调用时，把 ViewModel 里最新的 `targetRetirementAge` / `retirement_spending_monthly` 作为 request body 的 override 传过去。服务端优先用 request 值，否则回落到 `fire_goals` 表。这样既保证使用最新 UI 值，又不需要每次 load 都写库（避免 goal history 污染，理由见 S2-3）。

---

### S2-2：更新 BS_ChoosePathView 卡片语义

**文件**：`View/BudgetSetup/BS_ChoosePathView.swift`

**改动**：
- Header 文案从"Pick the savings rate that fits your life"改为目标驱动语言
- Recommended 卡片：标注"Best path to your goal"
- 每张卡片新增"Retire at age X"（来自 FIRECalculator 路径的 `retirement_age`）
- Phase 2 时 Accelerate 卡片显示警告标记
- Phase 0 时顶部加"You're on track"banner

---

### S2-3：更新 BudgetSetupViewModel.loadPlans()

**文件**：`View/BudgetSetup/BudgetSetupViewModel.swift`

**关键**：不传 `feasibility_result`（理由见 S2-1 的信任边界修正）。**也不要在 loadPlans 里 saveFireGoal**——`save-fire-goal/index.ts` L115–153 的逻辑是"把旧 active goal 失活再 insert 新记录"，如果 loadPlans 每次都调就会在 `fire_goals` 表制造一堆历史记录（用户进出 Step 5 N 次 → N 条 goal history），且有并发 insert 竞态。

**正确做法**：把 `target_retirement_age` / `retirement_spending_monthly` 作为 request body 的可选 override 传给 generate-plans。服务端按以下优先级取值：

1. request body 传了 → 用 request 值（处理"Step 4 刚改过还没提交"的情况）
2. 否则读 `fire_goals` 表的 active goal
3. 两者都没有 → 返回 400 `GOAL_NOT_FOUND`

```swift
func loadPlans() async {
    // 只读操作，无副作用。generate-plans 服务端会自己从 fire_goals 读最新 goal。
    guard let stats = spendingStats else { return }

    // 严格使用 typed API：不要手拼 [String: Any] body，也不要在 ViewModel 里直接调
    // authenticatedRequest(function:)（见本段末尾的"Typed API 硬规则"）。
    var request = GeneratePlansRequest(
        currentSavingsRate:  stats.currentSavingsRate,
        avgMonthlyIncome:    stats.avgMonthlyIncome,
        avgMonthlySavings:   stats.avgMonthlySavings,
        avgMonthlyFixed:     stats.avgMonthlyFixed,
        avgMonthlyFlexible:  stats.avgMonthlyFlexible,
        currentNetWorth:     currentNetWorth,
        currentAge:          currentAge
    )
    // 把当前 ViewModel 里的最新值作为 override 透传
    // （Step 4 刚改过还没点 Continue 时，保证 plans 用的是 UI 上的最新值）
    if targetRetirementAge > 0 {
        request.targetRetirementAge = targetRetirementAge
    }
    if retirementSpendingMonthly > 0 {
        request.retirementSpendingMonthly = retirementSpendingMonthly
    }
    request.accountIds = selectedAccountIds.isEmpty ? nil : Array(selectedAccountIds)
    request.month = currentMonthString  // 现有 month 字段

    let response = try await APIService.shared.generatePlans(data: request)
    plansResponse = response
}
```

**Typed API 硬规则**（文档约束，避免实现时回到手拼 JSON 的旧写法）：

- ViewModel / View 层**禁止**直接调 `APIService.shared.authenticatedRequest(function:)`。
- 每一个新接入的 edge function，**必须先**在 `Services/APIService.swift` 或 `Services/APIService+BudgetSetup.swift` 里加一个 typed wrapper（接收具体 `Encodable` 入参、返回 `Decodable` 出参）。
- 同理，入参结构体必须在 `Models/BudgetSetupModels.swift` 里定义命名清晰的 `Encodable` struct，不允许用 `[String: Any]` body 作为长期方案。
- 迁移中的临时代码如需手拼 body，标注 `// TODO: typed` 并在当次 PR 内收敛。

**读/写边界硬规则**（违反即回退）：

| 操作 | 是否写 DB | 触发条件 |
|------|:--------:|---------|
| `loadPlans()` / `loadGoalFeasibility()` / `loadDiagnosis()` | ❌ | 任何时候 |
| 任意 "load*" / "refresh*" 方法 | ❌ | 任何时候 |
| `saveFireGoal()` | ✅ | 仅在用户**显式点击** Goal Setup 页的 Continue 按钮，且 ViewModel 有 dirty goal state |
| 选定 Plan 的持久化 | ✅ | 仅在用户**显式点击** Step 5 的 Confirm Plan 按钮 |

**Dirty state 判定**：ViewModel 维护 `goalFormDirty: Bool`，用户在 Goal Setup 页改动 `targetRetirementAge` / `retirementSpendingMonthly` 时置 true；`saveFireGoal()` 成功后置 false。Continue 按钮：`if goalFormDirty { await saveFireGoal() }; navigateToNextStep()`。

**loadPlans 的参数传递**：需要的最新 goal 值作为 request body override 传给 generate-plans（见上方 S2-1 入参契约），不在 loadPlans 里触发任何写操作。

**可选增强（后续迭代）**：新增一个 `update-fire-goal` edge function，对现有 active goal 做 `UPDATE` 而不是 deactivate + insert。这样即便多次保存也不污染历史。本轮不强制要求。

**不要**把 `goalFeasibility` 结构体塞进请求体。

---

## SEGMENT 3：Budget 卡片重构（方案 D）

> 前置条件：S1 + S2 完成，目标驱动主线稳定后再动 Budget 卡片。

### S3-1：修复 CashflowView ratio bug（S0-1 已完成）
已在 S0-1 处理，此处不重复。

### S3-2：BudgetCard 编辑模式改为 Category-First

**文件**：`View/Cashflow/BudgetCard.swift`

**改动**：
- 删除现有编辑模式（需要先设 needs/wants 总额，再分 6 个子类）
- 改为：编辑按钮直接进入 Category 编辑器，每个 category 显示已花 / 预算额 / needs or wants 标签
- needs_budget / wants_budget 总额改为只读，由 category 金额加总自动派生：
  ```swift
  var needsBudget: Double { needsCategories.reduce(0) { $0 + $1.amount } }
  var wantsBudget: Double { wantsCategories.reduce(0) { $0 + $1.amount } }
  ```
- `BudgetEditPayload`：移除 `needsBudget / wantsBudget / needsRatio / wantsRatio` 作为独立输入字段，改为从 categoryBudgets 派生后传出

**展示层不变**：Ring chart + Scope Pill（All / Needs / Wants）保留，作为 read-only summary。

---

### S3-3：category_budgets 完整落库（依赖 S0-2）

S0-2 已修后端的写入和读取。S3-3 需要验证端到端：
- iOS 编辑 category 金额 → 保存 → `category_budgets` 正确写入 DB
- 重新打开 Cash Flow → `get-monthly-budget` 返回 `category_budgets` → `BudgetCard` 正确显示用户设定的 category 预算额（而不是静态默认值）

**验收标准**：`CashflowView.budgetCategories()` 里 `budgetMap = apiBudget.categoryBudgets ?? [:]` 拿到的不再是空字典。

---

### S3-4：术语统一（Roadmap 阶段 1）

**文件**：
- `View/BudgetSetup/BS_ConfirmView.swift`：Fixed → Needs，Flexible → Wants
- `View/BudgetSetup/BS_SpendingBreakdownView.swift`：同上
- `View/BudgetSetup/BudgetSetupViewModel.swift`：注释更新，`fixed_budget` → `needs_budget` 语义对齐（字段名保持与后端兼容，注释说明）

---

## 文件改动汇总

### 后端（Supabase Edge Functions）

| 文件 | 改动类型 | Segment |
|------|---------|---------|
| `migrations/20260414_add_category_budgets.sql` | **新建**：`budgets` 表加 `category_budgets JSONB` 列 | S0-2 |
| `_shared/fire-assumptions.ts` | **新建**：统一的财务假设常量（nominal/real return、withdrawal rate） | 全局假设 |
| `generate-monthly-budget/index.ts` | 新增 `category_budgets` 写入 | S0-2 |
| `get-monthly-budget/index.ts` | 新增 `category_budgets` 返回 | S0-2 |
| `generate-plans/index.ts` | 服务端重算 FIRECalculator，**不接受**客户端 feasibility_result | S2-1 |
| `get-active-fire-goal/index.ts` | 确认返回 `target_retirement_age`（已有则跳过） | S1-1a |
| `calculate-fire-goal/index.ts` | 不改，直接复用 | S1-2 |
| `_shared/fire-calculator.ts` | 把 hardcode 0.08 改为引用 `ASSUMPTIONS` | 全局假设 |
| `_shared/fire-math.ts` | 默认值改为引用 `ASSUMPTIONS` | 全局假设 |
| `save-fire-goal/index.ts` | 本轮不改（已支持 `target_retirement_age` optional）；v2 阶段性 enforce 见下 | S1-1 / 后续 |

### iOS

| 文件 | 改动类型 | Segment |
|------|---------|---------|
| `View/Cashflow/CashflowView.swift` | 修 ratio bug；分层 hasLinkedBank / budgetSetupCompleted | S0-1, S1-5 |
| `View/Cashflow/CashflowView.swift` | 修 ratio bug；分层 hasLinkedBank / budgetSetupCompleted；读 category_budgets by id | S0-1, S0-2a, S1-5 |
| `View/Cashflow/BudgetCard.swift` | 编辑模式改 category-first；写入 category_budgets 时用 id 做 key | S0-2a, S3-2 |
| `View/BudgetSetup/BS_GoalSetupView.swift` | 新增 target_retirement_age 必填输入 | S1-1 |
| `View/BudgetSetup/BS_DiagnosisView.swift` | 新增 Goal Feasibility 区块 | S1-3 |
| `View/BudgetSetup/BS_ChoosePathView.swift` | 更新卡片语义和文案 | S2-2 |
| `View/BudgetSetup/BS_AccountSelectionView.swift` | 分离连接与选择逻辑 | S1-4 |
| `View/BudgetSetup/BS_ConfirmView.swift` | 术语统一 fixed→needs，flexible→wants | S3-4 |
| `View/BudgetSetup/BS_SpendingBreakdownView.swift` | 术语统一 | S3-4 |
| `View/BudgetSetup/BudgetSetupViewModel.swift` | 新增 targetRetirementAge, goalFeasibility, loadGoalFeasibility(), restoreFromActiveFireGoal(); loadPlans 不传 feasibility_result | S1-1, S1-1a, S1-2, S2-3 |
| `View/Journey/JourneyView.swift` | 初始空状态（已连 onboarding 就显示粗估 FIRE number） + Todo list 组件 | S1-5 |
| `View/Journey/JourneyTodoList.swift` | **新建**：Todo list 组件 | S1-5 |
| `View/Journey/JourneyViewModel.swift` | FIRE Number 无数据时显示 --；粗估用 FIREAssumptions | S1-5 |
| `Models/BudgetSetupModels.swift` | 新增 GoalFeasibilityResult, FeasibilityPath；SaveFireGoalRequest 加 targetRetirementAge | S1-1, S1-2 |
| `Models/FIREAssumptions.swift` | **新建**：iOS 端统一财务假设常量 | 全局假设 |
| `Models/TransactionCategoryCatalog.swift` | **新增** `id(forDisplayedSubcategory:)` 工具方法 | S0-2a |
| `Services/APIService+BudgetSetup.swift` | **新增 typed method**：`calculateFireGoal(...)`；**扩展现有** `GeneratePlansRequest`（新增可选 `targetRetirementAge` / `accountIds` / `month`），继续复用已有 `generatePlans(data:)` 和 `APIService.getActiveFireGoal()`（不重复声明） | S1-1a, S1-2, S2-3 |

### 不需要改的文件（本轮）

| 文件 | 原因 |
|------|------|
| `generate-spending-plan/index.ts` | 接口语义不变，只需要接收已选定的 savings rate |
| `update-transaction-classification/index.ts` | 分类逻辑不变 |
| `View/Cashflow/TransactionDetailSheet.swift` | 用户纠正入口保持原样 |
| `Services/PlaidManager.swift` | 不变 |
| `Services/SupabaseManager.swift` | 不变 |

---

## 执行顺序（严格按此顺序，避免返工）

```
S-ASSUMPTIONS  建 fire-assumptions.ts + FIREAssumptions.swift，替换三处 hardcode  （2h，独立）
S0-1           修 cashflow_edit ratio bug                                          （独立，1h）
S0-2           migration + 后端 category_budgets 读写                              （2h）
S0-2a          iOS 侧 category_budgets key 统一为 id                                （3h，依赖 S0-2）
  ↓
S1-1           BS_GoalSetupView 加 target_retirement_age + PMT 预览                 （半天）
S1-1a          老用户/恢复流程：restoreFromActiveFireGoal() + 老用户兜底拦截         （半天）
S1-2           BudgetSetupViewModel 加 feasibility 状态 + loadGoalFeasibility()     （半天）
S1-3           BS_DiagnosisView 加 Goal Feasibility 区块                            （半天）
S1-4           BS_AccountSelectionView 分离连接与选择                               （半天）
S1-5           各 Tab 初始状态实现（含 JourneyTodoList 组件 + 粗估 FIRE number）     （1天）
  ↓
S2-1           generate-plans 后端重写（服务端重算，不接 feasibility_result）        （1天）
S2-2           BS_ChoosePathView 卡片语义更新                                       （半天）
S2-3           BudgetSetupViewModel.loadPlans() 只读不写，透传 override + account scope（2h）
  ↓
S3-1           （已在 S0-1 完成）
S3-2           BudgetCard 编辑模式改 category-first                                 （1.5天）
S3-3           category_budgets 端到端验收（key 为 id，读写一致）                    （半天）
S3-4           术语统一 fixed→needs/wants                                          （2h）
```

---

## 验收标准（每个 Segment 完成后检查）

**Segment 1 完成后：**
- [ ] 用户在 Step 0 不填 target_retirement_age 无法继续
- [ ] Step 4 Diagnosis 显示"当前每月存 $X，达成目标需要每月存 $Y，差 $Z"
- [ ] 可行性标签（on track / achievable / ambitious / impossible）显示正确
- [ ] 未连接 Plaid 时 Cash Flow 顶部日历和 Trend 空状态正常渲染
- [ ] Journey Tab 无数据时显示 Todo list

**Segment 2 完成后：**
- [ ] Step 5 的 Recommended 卡片符合 S2-1 定义的 fallback 映射（`recommended ?? plan_a ?? plan_b ?? current_path`）；Phase 1/2 等 recommended 为 nil 的场景下应正确落到 fallback，不视为失败
- [ ] 每张 Plan 卡片显示"Retire at age X"
- [ ] Phase 2 时 Accelerate 卡片有警告标记
- [ ] **只读不变量**：多次进入 / 退出 Step 5（触发 `loadPlans()` N 次），`fire_goals` 表**不新增**历史记录；active goal 仅在用户显式点击 Goal Setup 的 Continue（`saveFireGoal()`）时才写库

**Segment 3 完成后：**
- [ ] cashflow_edit 保存不再 400 报错
- [ ] Budget 卡片编辑入口直接进 category 列表，不再有独立的 needs/wants 金额输入
- [ ] 保存 category 预算后，重新打开 Cash Flow 看到的是用户设定的金额而非默认值
- [ ] BS_ConfirmView 中"Fixed"/"Flexible"文案已改为"Needs"/"Wants"
