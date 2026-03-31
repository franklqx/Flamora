# Flamora 数据来源全面审计报告

> 审计日期：2026-03-31
> 审计范围：所有 View/ 文件 + MockData.swift + BudgetSetupModels.swift
> 总计 Swift 文件：62 个

---

## 一、页面结构树

```
ContentView
├── OnboardingContainerView（首次启动）
│
└── MainTabView（主导航）
    │
    ├── Tab 0: JourneyContainerView
    │   └── JourneyView
    │       ├── PortfolioCard（净资产/图表）
    │       │   └── [fullScreenCover] → InvestmentView（切 Tab 2）
    │       ├── DailyQuoteCard
    │       ├── BudgetPlanCard（预算进度）
    │       │   └── [tap] → CashflowView（via onOpenCashflowDestination）
    │       └── SavingsRateCard（储蓄率）
    │           └── [tap] → SavingsTargetDetailView2（from MainTabView）
    │
    ├── Tab 1: CashflowView（现金流）
    │   ├── IncomeCard（收入环形图）
    │   │   ├── [card tap] → TotalIncomeDetailView（MockData.totalIncomeDetail）
    │   │   ├── [active tap] → IncomeDetailView（MockData.activeIncomeDetail）
    │   │   └── [passive tap] → IncomeDetailView（MockData.passiveIncomeDetail）
    │   ├── SavingsTargetCard（储蓄目标）
    │   │   └── [tap] → SavingsTargetDetailView2
    │   ├── BudgetCard（支出预算）
    │   │   ├── [total tap] → TotalSpendingAnalysisDetailView（MockData.totalSpendingDetail）
    │   │   ├── [needs tap] → SpendingAnalysisDetailView（MockData.needsSpendingDetail）
    │   │   └── [wants tap] → SpendingAnalysisDetailView（MockData.wantsSpendingDetail）
    │   └── TransactionsList（API）
    │       └── [see all] → AllTransactionsView（API binding）
    │           └── [row tap] → TransactionDetailSheet
    │
    └── Tab 2: InvestmentView（投资）
        ├── PortfolioCard（净资产/图表）
        ├── AssetAllocationCard（资产配置）
        │   └── [tap] → AssetAllocationDetailView（MockData）
        └── AccountsCard（账户列表）
            └── [row tap] → AccountDetailView（account: API，其余 MockData）
                └── TransactionDetailSheet
    │
    ├── [全局] BudgetSetupView（全屏覆盖，由 PlaidManager.showBudgetSetup 触发）
    │   步骤流程：
    │   accountSelection → loading → diagnosis → spendingBreakdown
    │   → choosePath → spendingPlan → confirm
    │
    └── [全局] SettingsView
```

---

## 二、逐文件审计

### 模板说明
```
文件：路径
用途：页面功能
──────────────────────
字段               | 数据来源
──────────────────────
问题：已发现的 bug 或待修复项
```

---

### 2.1 View/Journey/JourneyView.swift

**用途：** Journey Tab 首页，展示资产净值、日报、预算进度、储蓄率

| 字段 | 数据来源 |
|------|---------|
| `totalNetWorth` / `growthAmount` / `growthPercentage` | ✅ API — `APIService.getNetWorthSummary()` |
| `apiBudget` (spent, limit, remaining, selectedPlan) | ✅ API — `APIService.getMonthlyBudget(month:)` |
| `fireGoal` | ✅ API — `APIService.getActiveFireGoal()` |
| `daysLeft`（传给 BudgetPlanCard） | ❌ MockData — `MockData.journeyData.budget.daysLeft`（= 7） |
| daily quotes 文本 | ⚠️ 硬编码 — 3 条字符串在文件顶部直接写死 |

**问题：**
- `L80: let data = MockData.journeyData` → `data.budget.daysLeft` 被传给 BudgetPlanCard，永远显示 "7 days left"

---

### 2.2 View/Journey/BudgetPlanCard.swift

**用途：** 预算进度卡（Journey 页），有预算/无预算两种状态

| 字段 | 数据来源 |
|------|---------|
| `spent` / `limit` / `remaining` / `spentPercent` | ✅ API — 通过 `apiBudget: APIMonthlyBudget` 参数传入 |
| `needsSpent` / `wantsSpent` 进度条 | ✅ API — `apiBudget.needsSpent` / `apiBudget.wantsSpent` |
| `daysLeft` | ❌ MockData — 从 JourneyView 传入的 `MockData.journeyData.budget.daysLeft` |

**问题：**
- 本身逻辑干净，但上游 JourneyView 传入的是 MockData

---

### 2.3 View/Journey/PortfolioCard.swift

**用途：** 净资产卡（Journey + Investment 共用），含折线图 + 时间范围选择

| 字段 | 数据来源 |
|------|---------|
| `portfolioBalance` / `gainAmount` / `gainPercentage`（header） | ✅ API — 由父视图传入 |
| **全部 5 个时间范围折线图数据** | ❌ MockData — `private func mockData(for range:)` 内部硬编码 |

**硬编码数值（L394–L438）：**
```swift
// 1W: 7个点
[82400.0, 83100.0, 84200.0, 83800.0, 84900.0, 85100.0, 85240.0]
// 1M: 30个点
[76000, 77200, 75800, 78000, 79500, ... 85240]
// 3M: 15个点
[72000.0, 74500.0, 71000.0, ... 85240.0]
// YTD: 12个月
[64000.0, 67000.0, ... 85240.0]
// ALL: 12个月
[10000.0, 18000.0, ... 85240.0]
```

**问题：**
- 图表数据完全与 API 脱钩；`accountLinkedDate` 默认 `-30 天`，mock 数据直接可见

---

### 2.4 View/Journey/SavingsRateCard.swift

**用途：** 储蓄率卡（Journey 页），含 6 柱迷你图

| 字段 | 数据来源 |
|------|---------|
| `actualPct` / `savedAmount` / `targetAmount` | ✅ API — `apiBudget.savingsActual` / `apiBudget.savingsBudget` |
| 迷你 6 柱图历史数据 | ❌ MockData — `MockData.savingsByYear[year]?[month]`（L148） |

**问题：**
- 迷你图的历史储蓄数据读取 `MockData.savingsByYear`，不反映真实历史

---

### 2.5 View/Cashflow/CashflowView.swift

**用途：** Cashflow Tab 主页，汇总收入/储蓄/支出/交易

| 字段 | 数据来源 |
|------|---------|
| `apiBudget`（needsBudget, wantsBudget, etc.） | ✅ API — `APIService.getMonthlyBudget(month:)` |
| `currentSavings` / `needsTotal` / `wantsTotal` | ✅ API — 从 `apiBudget` 中提取 |
| `allTransactions` | ✅ API — `APIService.getTransactions(page:limit:)` |
| `income`（传给 IncomeCard） | ❌ MockData — `MockData.cashflowData.income`（L74） |
| `yearlyIncome`（传给 IncomeCard） | ❌ MockData — `MockData.yearlyIncome`（L75） |
| TotalIncomeDetailView 数据 | ❌ MockData — `MockData.totalIncomeDetail`（L124） |
| IncomeDetailView（主动收入）数据 | ❌ MockData — `MockData.activeIncomeDetail`（L127） |
| IncomeDetailView（被动收入）数据 | ❌ MockData — `MockData.passiveIncomeDetail`（L130） |
| TotalSpendingAnalysisDetailView 数据 | ❌ MockData — `MockData.totalSpendingDetail`（L133） |
| SpendingAnalysisDetailView（needs）数据 | ❌ MockData — `MockData.needsSpendingDetail`（L136） |
| SpendingAnalysisDetailView（wants）数据 | ❌ MockData — `MockData.wantsSpendingDetail`（L139） |

**问题：**
- 6 个 `fullScreenCover` 均传入 MockData 实例，所有收入/支出详情页数据虚假

---

### 2.6 View/Cashflow/BudgetCard.swift ⚠️ P0

**用途：** 支出预算卡（Cashflow 页），展示 Needs/Wants 分项进度

| 字段 | 数据来源 |
|------|---------|
| `spending.total` / `spending.needs` / `spending.wants` | ✅ API — 通过 `spending: Spending` 参数传入 |
| `spending.budgetLimit`（总额上限进度条） | ✅ API — 从 `apiBudget` 计算后传入 |
| **`apiBudget.needsBudget`（"/ $4,000"）** | ❌ **MockData** — `private let apiBudget = MockData.apiMonthlyBudget`（L16） |
| **`apiBudget.wantsBudget`（"/ $2,000"）** | ❌ **MockData** — 同上 |

**问题（P0 Bug）：**
```swift
// L16 — 硬编码 MockData，导致 Needs/Wants 预算上限永远显示 mock 值
private let apiBudget = MockData.apiMonthlyBudget
```
- `BudgetRowItem` 的 `total` 参数（L95, L102）始终读 MockData 的 `$4,000` 和 `$2,000`
- 修复方法：删除 L16，将 `apiBudget.needsBudget`/`apiBudget.wantsBudget` 改为从 `spending` 参数读取，或让父视图传入预算上限

---

### 2.7 View/Cashflow/IncomeCard.swift

**用途：** 收入环形图卡，Active/Passive 双弧，支持月/年切换

| 字段 | 数据来源 |
|------|---------|
| `income.total` / `income.active` / `income.passive` | ❌ MockData — `MockData.cashflowData.income` 由父视图传入 |
| `yearlyIncome` | ❌ MockData — `MockData.yearlyIncome` 由父视图传入 |

> 文件头注释已标注：`NOTE: Uses mock data today.`

**问题：**
- 整张卡片数据虚假；需 API 提供月度/年度收入分类数据

---

### 2.8 View/Cashflow/SavingsTargetCard.swift

**用途：** 储蓄目标卡，进度条 + "% Achieved"

| 字段 | 数据来源 |
|------|---------|
| `currentAmount` | ✅ API — `CashflowView` 传入 `$currentSavings`（= `apiBudget.savingsActual`） |
| `targetAmount` | ✅ API — `CashflowView` 传入 `apiBudget.savingsBudget` |

**状态：** 干净，无 MockData 引用。✅

---

### 2.9 View/Cashflow/SavingsTargetDetailView2.swift ⚠️ P0

**用途：** 储蓄总览详情（全屏），含年度趋势图 + 月度里程碑

| 字段 | 数据来源 |
|------|---------|
| `targetRate`（TARGET SAVING RATE） | ❌ **MockData** — `MockData.apiMonthlyBudget.savingsRatio / 100`（L11） |
| `targetAmount`（TARGET SAVING） | ❌ **MockData** — `MockData.apiMonthlyBudget.savingsBudget`（L12） |
| 年度趋势图所有月份数据 | ❌ MockData — `MockData.savingsByYear`（L28, `init()` 中） |
| 月度里程碑 12 格数据 | ❌ MockData — 同上 |
| `maxChartAmount`（图表 Y 轴上限） | ⚠️ 硬编码 — `private let maxChartAmount: Double = 3500`（L218） |

**问题（P0）：**
```swift
// L11–12：目标利率和目标金额从 MockData 读取
private let targetRate: Double = MockData.apiMonthlyBudget.savingsRatio / 100.0
private let targetAmount: Double = MockData.apiMonthlyBudget.savingsBudget
```
- 用户在 Budget Setup 设置的真实储蓄目标不会显示
- 应从 `APIService.getMonthlyBudget()` 获取，或通过 `@Environment` / 参数传入

---

### 2.10 View/Cashflow/TotalIncomeDetailView.swift

**用途：** 总收入详情页，含年度堆叠柱状图

| 字段 | 数据来源 |
|------|---------|
| 全部 `data`（trendsByYear, monthlyDataByYear） | ❌ MockData — `MockData.totalIncomeDetail` 由父视图传入 |
| 年度趋势柱状图 | ❌ MockData（同上） |
| 月度主动/被动收入详情 | ❌ MockData（同上） |

**问题：** 整个页面虚假数据

---

### 2.11 View/Cashflow/IncomeDetailView.swift

**用途：** 主动/被动收入分析详情，含月度趋势图 + 分类明细

| 字段 | 数据来源 |
|------|---------|
| 趋势图数据 | ❌ MockData — `MockData.activeIncomeDetail` / `MockData.passiveIncomeDetail` |
| 分类明细列表 | ❌ MockData — 同上 |
| SpendingAnalysisDetailView 趋势图 | ❌ MockData — `MockData.needsSpendingDetail` / `MockData.wantsSpendingDetail` |
| TotalSpendingAnalysisDetailView 趋势图 | ❌ MockData — `MockData.totalSpendingDetail` |
| SpendingCategoryTransactionsDetailView 商家列表 | ⚠️ 硬编码 — Netflix、Spotify、Adobe、Hulu 等商家名称模板 |

**问题：** 文件包含多个视图，全部依赖 MockData

---

### 2.12 View/Cashflow/AllTransactionsView.swift

**用途：** 全量交易列表，支持 All/Needs/Wants 筛选

| 字段 | 数据来源 |
|------|---------|
| `transactions` | ✅ API — `@Binding var transactions: [Transaction]`（由 CashflowView 传入 API 数据） |
| 分类筛选 | ✅ 运行时计算（`needs`/`wants` 字符串） |

**状态：** 干净，无 MockData 引用。✅

---

### 2.13 View/Investment/InvestmentView.swift ⚠️ P0

**用途：** Investment Tab 主页，含净资产/资产配置/账户列表

| 字段 | 数据来源 |
|------|---------|
| `apiNetWorth.totalNetWorth` | ✅ API — `APIService.getNetWorthSummary()` |
| **`portfolioBalance` fallback** | ❌ **硬编码** — `?? 85240.0`（L29） |
| **`gainAmount` fallback** | ❌ **硬编码** — `?? 3240.0`（L30） |
| **`gainPercentage` fallback** | ❌ **硬编码** — `?? 3.95`（L31） |
| `AssetAllocationCard` 数据 | ❌ MockData — `MockData.investmentData.allocation`（L39） |
| `AccountsCard` 账户列表 | ✅/❌ API 优先，`MockData.allAccounts` fallback（L76） |
| PortfolioCard 图表 | ❌ 内部硬编码（见 PortfolioCard 审计） |

**问题（P0）：**
```swift
// L29–31：API 返回 nil 时显示假数据，掩盖错误
portfolioBalance: apiNetWorth?.totalNetWorth ?? 85240.0,
gainAmount:       apiNetWorth?.growthAmount  ?? 3240.0,
gainPercentage:   apiNetWorth?.growthPercentage ?? 3.95,
```

---

### 2.14 View/Investment/AssetAllocationCard.swift

**用途：** 资产配置环形图卡

| 字段 | 数据来源 |
|------|---------|
| `allocation`（全部数据） | ❌ MockData — `MockData.investmentData.allocation`（由父视图传入） |

**问题：** 整张卡数据虚假；打开 `AssetAllocationDetailView` 也是 MockData

---

### 2.15 View/Investment/AccountsCard.swift

**用途：** 账户列表卡，含 "Updated X ago" 标签

| 字段 | 数据来源 |
|------|---------|
| `accounts`（账户列表） | ✅/❌ API 优先（`apiNetWorth.accounts`），fallback `MockData.allAccounts` |
| "Updated X ago" 标签 | ❌ MockData — `MockData.accountLastUpdated` |

---

### 2.16 View/Investment/AccountDetailView.swift

**用途：** 单个账户详情，含余额图表 + 持仓 / 交易列表

| 字段 | 数据来源 |
|------|---------|
| `account.balance` / `account.institution` | ✅ API — 通过 `account: Account` 参数传入 |
| 余额历史图表（1W/1M/3M/1Y） | ❌ MockData — `MockData.accountBalanceHistory[account.id]`（L35） |
| 持仓列表（投资账户） | ❌ MockData — `MockData.holdings.filter { $0.accountId == account.id }`（L31） |
| 交易列表（非投资账户） | ❌ MockData — `MockData.allTransactions.filter { $0.accountId == account.id }`（L19） |

**问题：** 除账户基本信息外，全部数据虚假

---

### 2.17 View/BudgetSetup/BudgetSetupView.swift

**用途：** Budget Setup 流程容器（7 步骤）

| 字段 | 数据来源 |
|------|---------|
| 步骤路由 / 流程管理 | ✅ ViewModel 状态（无 MockData） |

**问题（设计 Token 违规，P2）：**
- 使用 `Color(hex:)` 替代 `AppColors.*`
- 使用 `.system(size:weight:)` 替代 Font token
- 硬编码 `.padding(.horizontal, 26)` 等数值

---

### 2.18 View/BudgetSetup/BS_DiagnosisView.swift

**用途：** Budget Setup Step 2 — 财务快照（收入/储蓄/支出卡 + 月度柱状图 + AI 洞察）

| 字段 | 数据来源 |
|------|---------|
| `spendingStats.monthlyBreakdown` | ✅ API — `viewModel.spendingStats` |
| `totalTransactions` / `monthsAnalyzed` | ✅ API |
| AI 洞察列表 | ✅ API — `viewModel.diagnosis?.aiDiagnosis.insights` |
| 柱状图 | ✅ API — 从 `monthlyBreakdown` 计算 |

**问题（设计 Token 违规，P2）：**
- `L77: .font(.system(size: 28, weight: .bold))` → 应用 `.h1`
- `L83: Color(hex: "ABABAB")` → 应用 `AppColors.textSecondary`
- `L84: .lineSpacing(3)` → 应定义 token 或接受
- `L115: .font(.system(size: 9, weight: .semibold))` → 应用 `.miniLabel`
- `L127: Color.white.opacity(0.08)` → 应用 `AppColors.overlayWhiteWash`
- `L284: .font(.system(size: 15, weight: .semibold))` → 应用 `.figureSecondarySemibold`
- `L286: .foregroundStyle(.black)` → 应用 `AppColors.textInverse`
- `L288: .frame(height: 56)` → 应用 design token（已有 56pt 高度约定）
- `L292: .clipShape(RoundedRectangle(cornerRadius: 100))` → 应用 `AppRadius.button`
- `L293: .padding(.horizontal, 26)` → 应用 `AppSpacing.screenPadding`

---

### 2.19 View/BudgetSetup/BS_ConfirmView.swift

**用途：** Budget Setup Step 6 — 确认并保存预算

| 字段 | 数据来源 |
|------|---------|
| `viewModel.spendingPlan` / `viewModel.selectedPlan` | ✅ API — 来自 ViewModel |
| 预算分项（fixed/flexible/savings） | ✅ API |

**问题（P2 设计 Token 违规 + 术语问题）：**
- `Color(hex: "0A0A0C")` → `Color.black` 或 `AppColors.backgroundPrimary`
- `Color(hex: "F5C842")` 等渐变颜色 → 使用 `AppColors.gradientFlamePill` 或添加新 token
- `.padding(.horizontal, 26)` → `AppSpacing.screenPadding`
- VStack spacing 数值直接写死
- UI 显示 **"Fixed"** / **"Flexible"** 标签（见术语不一致分析章节）

---

### 2.20 View/BudgetSetup/BudgetSetupViewModel.swift

**用途：** Budget Setup 流程 ViewModel，管理 7 步状态

| 字段 | 数据来源 |
|------|---------|
| 账户列表 / Plaid 链接 | ✅ API — PlaidManager |
| 支出统计 `spendingStats` | ✅ API — `APIService.getBudgetSetupDiagnosis()` |
| 诊断 `diagnosis` | ✅ API |
| 支出方案 `spendingPlan` | ✅ API |
| 后端术语 `fixed` / `flexible` | 见术语章节 |

**状态：** ViewModel 本身不引用 MockData，数据流清晰。✅

---

### 2.21 View/MainTabView.swift

**用途：** 主导航容器，管理 Tab 切换和全局 Modal

| 字段 | 数据来源 |
|------|---------|
| Tab 0/1/2 导航 | ✅ 无数据依赖 |
| `.totalSpending` 路由 | ❌ MockData — `MockData.totalSpendingDetail`（L109） |
| `.savingsOverview` 路由 | ❌ MockData（`SavingsTargetDetailView2()` 内部读 MockData） |

---

## 三、MockData 引用完整列表

| 调用位置 | 引用 | 严重度 |
|---------|------|--------|
| `BudgetCard.swift:16` | `MockData.apiMonthlyBudget`（私有属性）| P0 |
| `SavingsTargetDetailView2.swift:11` | `MockData.apiMonthlyBudget.savingsRatio` | P0 |
| `SavingsTargetDetailView2.swift:12` | `MockData.apiMonthlyBudget.savingsBudget` | P0 |
| `SavingsTargetDetailView2.swift:28` | `MockData.savingsByYear` | P0 |
| `SavingsTargetDetailView2.swift:117` | `MockData.apiMonthlyBudget.savingsRatio` | P0 |
| `InvestmentView.swift:39` | `MockData.investmentData.allocation` | P1 |
| `InvestmentView.swift:76` | `MockData.allAccounts`（fallback） | P1 |
| `CashflowView.swift:27` | `MockData.cashflowData` | P1 |
| `CashflowView.swift:75` | `MockData.yearlyIncome` | P1 |
| `CashflowView.swift:124` | `MockData.totalIncomeDetail` | P1 |
| `CashflowView.swift:127` | `MockData.activeIncomeDetail` | P1 |
| `CashflowView.swift:130` | `MockData.passiveIncomeDetail` | P1 |
| `CashflowView.swift:133` | `MockData.totalSpendingDetail` | P1 |
| `CashflowView.swift:136` | `MockData.needsSpendingDetail` | P1 |
| `CashflowView.swift:139` | `MockData.wantsSpendingDetail` | P1 |
| `MainTabView.swift:109` | `MockData.totalSpendingDetail` | P1 |
| `JourneyView.swift:24` | `MockData.journeyData` → `daysLeft` | P1 |
| `SavingsRateCard.swift:148` | `MockData.savingsByYear` | P1 |
| `AccountDetailView.swift:19` | `MockData.allTransactions` | P1 |
| `AccountDetailView.swift:31` | `MockData.holdings` | P1 |
| `AccountDetailView.swift:35` | `MockData.accountBalanceHistory` | P1 |
| `AccountsCard.swift` | `MockData.accountLastUpdated` | P2 |
| `PortfolioCard.swift:388–438` | 内部硬编码（非 MockData，但等效） | P1 |

---

## 四、Trend 图表数据来源汇总

| 图表 | 所在文件 | 数据来源 | 真实？ |
|------|---------|---------|--------|
| PortfolioCard 折线图（5 范围） | PortfolioCard.swift:388 | 内部 `mockData(for:)` 函数硬编码 | ❌ |
| SavingsRateCard 迷你 6 柱图 | SavingsRateCard.swift:148 | `MockData.savingsByYear` | ❌ |
| TotalIncomeDetailView 年度柱状图 | TotalIncomeDetailView.swift | `MockData.totalIncomeDetail.trendsByYear` | ❌ |
| IncomeDetailView 月度趋势图（主动） | IncomeDetailView.swift | `MockData.activeIncomeDetail` | ❌ |
| IncomeDetailView 月度趋势图（被动） | IncomeDetailView.swift | `MockData.passiveIncomeDetail` | ❌ |
| SpendingAnalysisDetailView 趋势图（Needs） | IncomeDetailView.swift | `MockData.needsSpendingDetail` | ❌ |
| SpendingAnalysisDetailView 趋势图（Wants） | IncomeDetailView.swift | `MockData.wantsSpendingDetail` | ❌ |
| TotalSpendingAnalysisDetailView 趋势图 | IncomeDetailView.swift | `MockData.totalSpendingDetail` | ❌ |
| SavingsTargetDetailView2 年度趋势柱状图 | SavingsTargetDetailView2.swift:28 | `MockData.savingsByYear` | ❌ |
| AccountDetailView 余额历史折线图 | AccountDetailView.swift:35 | `MockData.accountBalanceHistory` | ❌ |
| **BS_DiagnosisView 月度柱状图** | BS_DiagnosisView.swift | `viewModel.spendingStats.monthlyBreakdown` | ✅ **唯一真实图表** |

**结论：** 全 app 共 11 个趋势图，仅 BS_DiagnosisView 1 个使用 API 真实数据，其余 10 个全部使用 MockData 或内部硬编码。

---

## 五、术语不一致分析

### 5.1 两套系统的定义

| 系统 | 术语 | 出处 |
|------|------|------|
| Budget Setup 后端 / API 响应 | `fixed` / `flexible` | `BudgetSetupViewModel`，`MonthlyBreakdownItem`，`SpendingPlanOption` |
| 主 App API 模型 | `needs` / `wants` | `APIMonthlyBudget`（`needsBudget`/`wantsBudget`/`needsSpent`/`wantsSpent`） |
| 主 App UI 显示 | "Needs" / "Wants" | `BudgetCard`、`BudgetPlanCard`、`AllTransactionsView` |
| Budget Setup UI 显示 | "Fixed" / "Flexible" | `BS_ConfirmView`、`BS_SpendingBreakdownView` |

### 5.2 术语映射关系

```
Budget Setup 分析阶段：
  fixed    ← 固定支出（房租、贷款等）
  flexible ← 弹性支出（餐饮、娱乐等）

主 App 预算执行阶段：
  needs  ← 必要支出（≈ fixed 的超集）
  wants  ← 消费支出（≈ flexible 的超集）
```

> 两者语义相近但不完全对等。Budget Setup 以**支出性质**分类（固定/弹性），主 App 以**需求层级**分类（必要/想要）。

### 5.3 用户体验断层

- 用户在 Budget Setup Step 2（BS_DiagnosisView）看到 "Fixed"、"Flexible" 分类
- 设置完成后，主 App 卡片改为 "Needs"、"Wants"
- 没有任何 UI 说明两者的映射关系，新用户可能困惑

### 5.4 代码层面的映射

`BudgetSetupViewModel` 中（推测，未直接读取相关函数）：
- `fixed expenses` → 储存为 Budget Setup API 的 `fixedExpenses`
- 最终确认方案时，后端将 `fixed`/`flexible` 转换为 `needs`/`wants` budget

**建议：**
1. 在 BS_ConfirmView 中将 "Fixed"/"Flexible" 改为 "Needs"/"Wants"，与主 App 保持一致
2. 或在 Budget Setup 最后一步增加说明："Fixed & Flexible 将归类为 Needs & Wants"

---

## 六、硬编码数值汇总

| 位置 | 硬编码值 | 含义 | 影响 |
|------|---------|------|------|
| `PortfolioCard.swift:395` | `[82400.0 … 85240.0]`（1W 7点） | 图表数据 | 与真实账户无关 |
| `PortfolioCard.swift:401` | `[76000 … 85240]`（1M 30点） | 图表数据 | 同上 |
| `PortfolioCard.swift:413` | `[72000.0 … 85240.0]`（3M 15点） | 图表数据 | 同上 |
| `PortfolioCard.swift:425` | `[64000.0 … 85240.0]`（YTD 12点） | 图表数据 | 同上 |
| `PortfolioCard.swift:432` | `[10000.0 … 85240.0]`（ALL 12点） | 图表数据 | 同上 |
| `InvestmentView.swift:29` | `?? 85240.0` | 净资产 fallback | 掩盖 API 错误 |
| `InvestmentView.swift:30` | `?? 3240.0` | 涨幅金额 fallback | 掩盖 API 错误 |
| `InvestmentView.swift:31` | `?? 3.95` | 涨幅百分比 fallback | 掩盖 API 错误 |
| `SavingsTargetDetailView2.swift:218` | `3500` | 储蓄图表 Y 轴上限 | 不随目标动态调整 |
| `BS_DiagnosisView.swift:293` | `26`（padding） | 水平内边距 | Token 违规（应用 `AppSpacing.screenPadding`） |
| `BS_ConfirmView.swift:29` | `20`（spacing） | VStack 间距 | Token 违规 |
| `BS_ConfirmView.swift:30` | `60`（top spacer） | 顶部占位高度 | Token 违规 |
| `JourneyView.swift:24` | `MockData.journeyData.budget.daysLeft`（= 7） | 月内剩余天数 | 永远显示 7 天 |

---

## 七、优先级问题汇总

### P0 — 立即修复（数据显示直接错误，影响核心功能）

#### P0-1: `BudgetCard.swift:16` — Needs/Wants 预算上限始终显示 MockData
```swift
// 问题代码
private let apiBudget = MockData.apiMonthlyBudget

// 影响
Needs 行：显示 "/ $4,000"（MockData 值，与用户设置无关）
Wants 行：显示 "/ $2,000"（同上）

// 修复思路
删除 L16，将 needsBudget/wantsBudget 改为从 spending 参数或新参数传入
```

#### P0-2: `SavingsTargetDetailView2.swift:11-12` — 储蓄目标读 MockData
```swift
// 问题代码
private let targetRate: Double = MockData.apiMonthlyBudget.savingsRatio / 100.0
private let targetAmount: Double = MockData.apiMonthlyBudget.savingsBudget

// 影响
"TARGET SAVING RATE" 和 "TARGET SAVING" 始终显示 Mock 值
月度里程碑的达标判断基于 Mock 目标

// 修复思路
在 init() 传入 targetRate/targetAmount 参数，由调用方从 API 提供
```

#### P0-3: `InvestmentView.swift:29-31` — 硬编码 fallback 值掩盖 API 错误
```swift
// 问题代码
portfolioBalance: apiNetWorth?.totalNetWorth ?? 85240.0,
gainAmount:       apiNetWorth?.growthAmount  ?? 3240.0,
gainPercentage:   apiNetWorth?.growthPercentage ?? 3.95,

// 影响
API 失败时显示假数据，用户误以为数据真实

// 修复思路
fallback 改为 0.0，并在 PortfolioCard 中处理 "No data" 状态
```

---

### P1 — 计划修复（MockData 未替换，功能不完整）

| 编号 | 文件 | 问题 |
|------|------|------|
| P1-1 | `PortfolioCard.swift` | 图表数据（1W/1M/3M/YTD/ALL）全部硬编码，与真实账户无关 |
| P1-2 | `CashflowView.swift` | 6 个详情页全部传入 MockData（income, spending 分析） |
| P1-3 | `IncomeCard.swift` | income / yearlyIncome 全部来自 MockData |
| P1-4 | `TotalIncomeDetailView.swift` | 年度收入趋势图全 MockData |
| P1-5 | `IncomeDetailView.swift` | 收入/支出分析详情全 MockData |
| P1-6 | `SavingsRateCard.swift` | 迷你图历史储蓄数据读 `MockData.savingsByYear` |
| P1-7 | `AssetAllocationCard.swift` | 资产配置全 MockData（含 AssetAllocationDetailView） |
| P1-8 | `AccountDetailView.swift` | 余额图、持仓、交易全 MockData |
| P1-9 | `JourneyView.swift` | `daysLeft` 读 `MockData.journeyData.budget.daysLeft` 永远 = 7 |
| P1-10 | `MainTabView.swift` | `.totalSpending` 路由传 `MockData.totalSpendingDetail` |

---

### P2 — 代码质量（不影响功能，违反 CLAUDE.md 设计规范）

| 文件 | 问题类型 | 具体位置 |
|------|---------|---------|
| `BS_DiagnosisView.swift` | Font token 违规 | L77, L115, L284 等多处 `.system(size:weight:)` |
| `BS_DiagnosisView.swift` | Color token 违规 | L24, L83 等 `Color(hex:)` |
| `BS_DiagnosisView.swift` | Spacing token 违规 | L32, L35, L39, L293 等硬编码 padding |
| `BS_DiagnosisView.swift` | Radius token 违规 | L128, L214 硬编码 `cornerRadius: 14` |
| `BS_ConfirmView.swift` | Font token 违规 | 多处 `.system(size:weight:)` |
| `BS_ConfirmView.swift` | Color token 违规 | L16–19 `Color(hex:)` 渐变颜色 |
| `BS_ConfirmView.swift` | Spacing token 违规 | L28–29 `spacing: 20`, `height: 60` 等 |
| `SavingsTargetDetailView2.swift` | Font token 违规 | L118, L133 `.system(size: 26, weight: .bold)` |
| `SavingsTargetDetailView2.swift` | Radius token 违规 | L380 `.cornerRadius(16)` 硬编码 |
| `SavingsTargetDetailView2.swift` | Spacing token 违规 | `padding: 14`, `spacing: 16` 等多处 |

---

## 八、修复优先级路线图

```
Week 1 (P0 — 立即修复)
  ├── fix: BudgetCard — 删除硬编码 apiBudget，从参数传入预算上限
  ├── fix: SavingsTargetDetailView2 — 接受 targetRate/targetAmount 参数
  └── fix: InvestmentView — 移除硬编码 fallback 值

Week 2–3 (P1 — 核心 Mock 替换)
  ├── feat: PortfolioCard — 接入 API 历史净资产数据（按时间范围）
  ├── feat: IncomeCard + TotalIncomeDetailView — 接入 API 收入分类数据
  ├── feat: AccountDetailView — 接入 API 余额历史、持仓、交易
  ├── fix: JourneyView — daysLeft 改为运行时计算（当月剩余天数）
  └── feat: SavingsRateCard — 迷你图接入真实历史储蓄 API

Week 4 (P2 — Token 合规)
  ├── refactor: BS_DiagnosisView — 替换所有 system font / Color(hex) / hardcoded spacing
  ├── refactor: BS_ConfirmView — 同上
  └── refactor: SavingsTargetDetailView2 — 同上
```

---

*报告生成于 2026-03-31，基于代码静态分析，共审计 View/ 目录下全部 Swift 文件。*
