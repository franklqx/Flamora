# Flamora 完整修复路线图（基于审计报告）

> 更新日期：2026-03-31
> 基于 AUDIT_REPORT.md 审计结果

---

## 阶段 0：P0 Bug 修复（预计 1-2 小时）

这三个 bug 导致用户看到的数据是错误的，必须最先修。

| # | 文件 | 问题 | 修复方式 |
|---|------|------|---------|
| 0.1 | BudgetCard.swift:16 | `private let apiBudget = MockData.apiMonthlyBudget` 导致 Needs/Wants 预算上限永远是 $4,000/$2,000 | 删除 L16，让父视图（CashflowView）把真实的 apiBudget 传进来 |
| 0.2 | SavingsTargetDetailView2.swift:11-12 | targetRate/targetAmount 直接从 MockData 读取 | 改为 init 参数传入，调用方从 API 提供 |
| 0.3 | InvestmentView.swift:29-31 | fallback 值 `?? 85240.0` 等掩盖 API 错误 | 改为 `?? 0.0`，在 PortfolioCard 处理无数据状态 |
| 0.4 | JourneyView.swift:24 | `daysLeft` 永远 = 7（MockData） | 改为运行时计算当月剩余天数 |

---

## 阶段 1：术语统一（预计 2-3 小时）

Budget Setup 用 fixed/flexible，主页和 Cashflow 用 needs/wants，用户会困惑。

| # | 任务 | 涉及文件 |
|---|------|---------|
| 1.1 | 决定统一用哪套术语 | 产品决策 |
| 1.2 | BS_ConfirmView 中 "Fixed"/"Flexible" 标签改为统一术语 | BS_ConfirmView.swift |
| 1.3 | BS_SpendingBreakdownView 同步更改 | BS_SpendingBreakdownView.swift |
| 1.4 | 确保 API 层面 fixed→needs / flexible→wants 映射正确 | BudgetSetupViewModel.swift, generate-monthly-budget |

---

## 阶段 2：Cashflow Tab 接真实数据（预计 3-5 天，最核心）

Cashflow 是用户使用最频繁的页面，6 个详情页全部是 MockData。

### 2A：Income 数据（需要新 API）

| # | 任务 | 说明 |
|---|------|------|
| 2A.1 | 创建 get-income-summary Edge Function | 从 transactions 表聚合 flamora_category=income 的数据，按月/年分组，区分 active/passive |
| 2A.2 | iOS 新增 API 方法和 Model | APIIncomeResponse 等 |
| 2A.3 | IncomeCard.swift 接真实数据 | 替换 MockData.cashflowData.income 和 MockData.yearlyIncome |
| 2A.4 | TotalIncomeDetailView 接真实数据 | 替换 MockData.totalIncomeDetail，包含年度趋势图 |
| 2A.5 | IncomeDetailView (Active) 接真实数据 | 替换 MockData.activeIncomeDetail |
| 2A.6 | IncomeDetailView (Passive) 接真实数据 | 替换 MockData.passiveIncomeDetail |

### 2B：Spending 详情数据（需要新 API）

| # | 任务 | 说明 |
|---|------|------|
| 2B.1 | 创建 get-spending-detail Edge Function | 从 transactions 表按 flamora_category + flamora_subcategory 聚合，按月分组 |
| 2B.2 | TotalSpendingAnalysisDetailView 接真实数据 | 替换 MockData.totalSpendingDetail |
| 2B.3 | SpendingAnalysisDetailView (Needs) 接真实数据 | 替换 MockData.needsSpendingDetail |
| 2B.4 | SpendingAnalysisDetailView (Wants) 接真实数据 | 替换 MockData.wantsSpendingDetail |
| 2B.5 | SpendingCategoryTransactionsDetailView 接真实数据 | 替换硬编码的 Netflix/Spotify 等商家 |

### 2C：Savings 详情

| # | 任务 | 说明 |
|---|------|------|
| 2C.1 | SavingsTargetDetailView2 年度趋势图接真实数据 | 替换 MockData.savingsByYear，从 transactions 表按月计算 income-expenses |
| 2C.2 | 月度里程碑显示真实数据 | 基于每月实际储蓄 vs 目标 |

---

## 阶段 3：Home Tab 补全（预计 1-2 天）

| # | 任务 | 说明 |
|---|------|------|
| 3.1 | SavingsRateCard 迷你图接真实数据 | 替换 MockData.savingsByYear，从最近 6 个月数据计算 |
| 3.2 | 断开连接后主页刷新 | 断开银行后所有卡片恢复初始状态 |
| 3.3 | 页面切换闪烁修复 | 加 loading 状态或缓存数据 |

---

## 阶段 4：Investment Tab 接真实数据（预计 3-5 天）

| # | 任务 | 说明 |
|---|------|------|
| 4.1 | PortfolioCard 图表接真实数据 | 需要 net_worth_history 表按时间范围查询的 API |
| 4.2 | AssetAllocationCard 接真实数据 | 从 investment_holdings + securities 表聚合 |
| 4.3 | AssetAllocationDetailView 接真实数据 | 同上，详细展开 |
| 4.4 | AccountDetailView 余额历史图 | 需要账户级别的 balance 历史 API |
| 4.5 | AccountDetailView 持仓列表 | 从 investment_holdings 表 |
| 4.6 | AccountDetailView 交易列表 | 从 transactions 表按 account 过滤 |
| 4.7 | AccountsCard "Updated X ago" | 从 plaid_items.last_synced 计算 |

---

## 阶段 5：代码质量（P2，预计 1 天）

| # | 任务 |
|---|------|
| 5.1 | BS_DiagnosisView 设计 token 合规 |
| 5.2 | BS_ConfirmView 设计 token 合规 |
| 5.3 | SavingsTargetDetailView2 设计 token 合规 |

---

## 建议推进顺序

```
今天/明天：阶段 0（P0 Bug 修复）→ 最快见效
接下来：阶段 1（术语统一）→ 小改动但影响用户认知
然后：阶段 2（Cashflow 接真实数据）→ 最核心最耗时
再：阶段 3（Home 补全）
最后：阶段 4 + 5（Investment + 代码质量）
```
