# 🔥 FIRE 财务 App - API 数据契约文档 v1.0

> **更新日期：** 2026-02-05  
> **维护人：** 后端开发者  
> **前端使用指南：** 所有 Mock Data 必须严格遵循此格式

---

## 🌐 Base URL
```
Production: https://YOUR_SUPABASE_PROJECT_REF.supabase.co/functions/v1
Development: 同上（使用测试用户）
```

---

## 🔐 认证

所有 API 需要在 Header 中携带：
```
Authorization: Bearer YOUR_SUPABASE_ANON_KEY
```

**开发阶段：** 使用测试用户 `00000000-0000-0000-0000-000000000001`

---

## 📊 通用响应格式

### 成功响应
```json
{
  "success": true,
  "data": { /* 具体数据 */ },
  "meta": {
    "timestamp": "2026-02-05T13:30:00Z",
    "user_id": "uuid"
  }
}
```

### 错误响应
```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "field": "fieldName"  // 可选，表单验证错误时使用
  }
}
```

### 常见错误码

| 错误码 | HTTP Status | 说明 |
|--------|-------------|------|
| `UNAUTHORIZED` | 401 | 未登录或 token 无效 |
| `FORBIDDEN` | 403 | 无权限访问（免费用户访问付费功能）|
| `NOT_FOUND` | 404 | 资源不存在 |
| `VALIDATION_ERROR` | 400 | 输入数据验证失败 |
| `INTERNAL_SERVER_ERROR` | 500 | 服务器错误 |

---

## 📋 API 列表

### 1. 核心 FIRE 计算（已完成 ✅）

#### 1.1 计算 FIRE 目标

**`POST /calculate-fire-goal`**

**用途：** Onboarding 或 Simulator 时计算 FIRE 可行性

**请求体：**
```json
{
  "current_age": 30,
  "target_retirement_age": 50,
  "desired_monthly_expenses": 3000,
  "current_net_worth": 200000,
  "monthly_income": 10000,
  "current_monthly_expenses": 5000
}
```

**响应示例（Phase 0）：**
```json
{
  "success": true,
  "data": {
    "phase": 0,
    "strategy": "goal_achievable",
    "fire_number": 900000.00,
    "gap_to_fire": 700000.00,
    "required_monthly_contribution": 1188.41,
    "required_savings_rate": 11.88,
    "years_to_retirement": 20,
    "is_achievable": true
  },
  "meta": {
    "timestamp": "2026-02-05T13:30:00Z",
    "user_id": "00000000-0000-0000-0000-000000000001"
  }
}
```

**响应示例（Phase 2）：**
```json
{
  "success": true,
  "data": {
    "phase": 2,
    "strategy": "user_choice",
    "fire_number": 1500000.00,
    "gap_to_fire": 1300000.00,
    "plan_a": {
      "type": "time_priority",
      "retirement_age": 54,
      "monthly_expenses": 5000,
      "savings_rate": 20,
      "required_monthly_contribution": 2000
    },
    "plan_b": {
      "type": "lifestyle_adjustment",
      "retirement_age": 45,
      "monthly_expenses": 4500,
      "savings_rate": 40.8,
      "required_monthly_contribution": 4080
    },
    "recommendation": "plan_b"
  }
}
```

---

#### 1.2 保存 FIRE 目标

**`POST /save-fire-goal`**

**用途：** 用户确认目标后保存到数据库

**请求体：**
```json
{
  "current_age": 30,
  "target_retirement_age": 50,
  "desired_monthly_expenses": 3000,
  "fire_number": 900000,
  "required_monthly_contribution": 1188.41,
  "required_savings_rate": 11.88,
  "adjustment_phase": 0,
  "adjustment_strategy": "goal_achievable",
  "user_selected_plan": null,  // Phase 2 时填 "plan_a" 或 "plan_b"
  "adjusted_retirement_age": null,
  "adjusted_monthly_expenses": null
}
```

**响应：**
```json
{
  "success": true,
  "data": {
    "goal_id": "a6d9e6d5-46ef-48d8-a85a-45beb992506f",
    "user_id": "00000000-0000-0000-0000-000000000001",
    "current_age": 30,
    "target_retirement_age": 50,
    "desired_monthly_expenses": 3000,
    "fire_number": 900000,
    "required_monthly_contribution": 1188.41,
    "required_savings_rate": 11.88,
    "adjusted_retirement_age": null,
    "adjusted_monthly_expenses": null,
    "adjustment_phase": 0,
    "adjustment_strategy": "goal_achievable",
    "user_selected_plan": null,
    "is_active": true,
    "created_at": "2026-02-05T13:25:44Z",
    "updated_at": "2026-02-05T13:25:44Z"
  }
}
```

---

#### 1.3 生成月度预算

**`POST /generate-monthly-budget`**

**用途：** 基于 FIRE 目标生成预算

**请求体：**
```json
{
  "month": "2026-02-01"  // 可选，默认当前月
}
```

**响应：**
```json
{
  "success": true,
  "data": {
    "budget_id": "b8410610-d803-471d-929c-89fcbabb920c",
    "month": "2026-02-01",
    "needs_budget": 5000.00,
    "wants_budget": 3000.00,
    "savings_budget": 2000.00,
    "needs_ratio": 50.00,
    "wants_ratio": 30.00,
    "savings_ratio": 20.00,
    "is_custom": false,
    "needs_spent": 0.00,
    "wants_spent": 0.00,
    "savings_actual": 0.00,
    "created_at": "2026-02-05T13:00:21Z"
  }
}
```

**错误示例（预算已存在）：**
```json
{
  "success": false,
  "error": {
    "code": "BUDGET_ALREADY_EXISTS",
    "message": "Budget for 2026-02-01 already exists",
    "existing_budget": { /* 现有预算数据 */ }
  }
}
```

---

### 2. 读取 API（待开发 ⬜）

#### 2.1 获取活跃 FIRE 目标

**`GET /active-fire-goal`**

**用途：** Journey 页面显示当前目标

**响应：**
```json
{
  "success": true,
  "data": {
    "goal_id": "a6d9e6d5-46ef-48d8-a85a-45beb992506f",
    "fire_number": 900000.00,
    "current_net_worth": 200000.00,
    "gap_to_fire": 700000.00,
    "required_savings_rate": 11.88,
    "target_retirement_age": 50,
    "current_age": 30,
    "years_remaining": 20,
    "progress_percentage": 22.22,  // (200000 / 900000) * 100
    "on_track": true,
    "created_at": "2026-02-05T13:25:44Z"
  }
}
```

**错误（无活跃目标）：**
```json
{
  "success": false,
  "error": {
    "code": "NO_ACTIVE_GOAL",
    "message": "No active FIRE goal found. Please create one first."
  }
}
```

---

#### 2.2 获取月度预算

**`GET /monthly-budget?month=2026-02`**

**用途：** Cashflow 页面显示预算

**查询参数：**
- `month`（可选）：YYYY-MM 格式，默认当前月

**响应：**
```json
{
  "success": true,
  "data": {
    "budget_id": "b8410610-d803-471d-929c-89fcbabb920c",
    "month": "2026-02-01",
    "needs_budget": 5000.00,
    "wants_budget": 3000.00,
    "savings_budget": 2000.00,
    "needs_spent": 2450.30,
    "wants_spent": 1820.50,
    "savings_actual": 2100.00,
    "needs_ratio": 50.00,
    "wants_ratio": 30.00,
    "savings_ratio": 20.00,
    "is_custom": false,
    "progress": {
      "needs_percentage": 49.01,  // (2450.30 / 5000) * 100
      "wants_percentage": 60.68,
      "on_track": true  // savings_actual >= savings_budget
    }
  }
}
```

---

#### 2.3 获取用户档案

**`GET /user-profile`**

**用途：** 各页面获取用户基本信息

**响应：**
```json
{
  "success": true,
  "data": {
    "profile_id": "uuid",
    "user_id": "00000000-0000-0000-0000-000000000001",
    "monthly_income": 10000.00,
    "current_net_worth": 200000.00,
    "current_monthly_expenses": 5000.00,
    "currency_code": "USD",
    "timezone": "America/New_York",
    "onboarding_completed": true,
    "onboarding_step": 5,
    "created_at": "2026-02-01T10:00:00Z",
    "updated_at": "2026-02-05T13:25:44Z"
  }
}
```

---

#### 2.4 获取净资产概览

**`GET /net-worth-summary`**

**用途：** Journey 页面 Net Worth Card

**响应：**
```json
{
  "success": true,
  "data": {
    "total_net_worth": 208240.00,
    "previous_net_worth": 200000.00,
    "growth_amount": 8240.00,
    "growth_percentage": 4.12,
    "as_of_date": "2026-02-05",
    "breakdown": {
      "assets": 250000.00,
      "liabilities": 41760.00
    },
    "accounts": [
      {
        "account_id": "uuid",
        "name": "Fidelity 401(k)",
        "type": "investment",
        "balance": 150000.00,
        "institution": "Fidelity"
      },
      {
        "account_id": "uuid",
        "name": "Chase Checking",
        "type": "cash",
        "balance": 25000.00,
        "institution": "Chase"
      }
    ]
  }
}
```

---

### 3. Onboarding API（待开发 ⬜）

#### 3.1 创建用户档案

**`POST /create-user-profile`**

**用途：** Onboarding 完成后保存用户信息

**请求体：**
```json
{
  "age": 30,
  "location": "New York, NY",
  "currency": "USD",
  "rough_monthly_income": 8000,
  "rough_monthly_expenses": 5000,
  "rough_net_worth": 200000,
  "motivation": "early_retirement"  // 可选
}
```

**响应：**
```json
{
  "success": true,
  "data": {
    "profile_id": "uuid",
    "fire_summary": {
      "fire_number": 900000.00,
      "years_to_fire": 20,
      "target_retirement_age": 50,
      "feasible": true,
      "message": "You're on track to retire at 50! 🎉"
    }
  }
}
```

---

## 📦 数据模型定义

### FireGoal（FIRE 目标）
```typescript
interface FireGoal {
  goal_id: string
  user_id: string
  current_age: number
  target_retirement_age: number
  desired_monthly_expenses: number
  fire_number: number
  required_monthly_contribution: number
  required_savings_rate: number
  adjusted_retirement_age: number | null
  adjusted_monthly_expenses: number | null
  adjustment_phase: 0 | 1 | 2 | 3
  adjustment_strategy: 'goal_achievable' | 'time_only' | 'user_choice' | 'dual_adjustment' | 'impossible'
  user_selected_plan: 'plan_a' | 'plan_b' | null
  is_active: boolean
  created_at: string  // ISO 8601
  updated_at: string
}
```

### MonthlyBudget（月度预算）
```typescript
interface MonthlyBudget {
  budget_id: string
  user_id: string
  month: string  // YYYY-MM-DD（总是月初）
  needs_budget: number
  wants_budget: number
  savings_budget: number
  needs_spent: number
  wants_spent: number
  savings_actual: number
  needs_ratio: number
  wants_ratio: number
  savings_ratio: number
  is_custom: boolean
  created_at: string
  updated_at: string
}
```

### UserProfile（用户档案）
```typescript
interface UserProfile {
  profile_id: string
  user_id: string
  monthly_income: number
  current_net_worth: number
  current_monthly_expenses: number
  currency_code: string
  timezone: string
  onboarding_completed: boolean
  onboarding_step: number
  created_at: string
  updated_at: string
}
```

---

## 🎨 前端 Mock Data 模板
```swift
// MockData.swift

import Foundation

struct MockData {
    // MARK: - Fire Goal
    static let fireGoal = FireGoal(
        goalId: "mock-goal-id",
        userId: "mock-user-id",
        currentAge: 30,
        targetRetirementAge: 50,
        desiredMonthlyExpenses: 3000,
        fireNumber: 900000,
        requiredMonthlyContribution: 1188.41,
        requiredSavingsRate: 11.88,
        adjustedRetirementAge: nil,
        adjustedMonthlyExpenses: nil,
        adjustmentPhase: 0,
        adjustmentStrategy: "goal_achievable",
        userSelectedPlan: nil,
        isActive: true,
        createdAt: Date(),
        updatedAt: Date()
    )
    
    // MARK: - Monthly Budget
    static let monthlyBudget = MonthlyBudget(
        budgetId: "mock-budget-id",
        userId: "mock-user-id",
        month: "2026-02-01",
        needsBudget: 5000,
        wantsBudget: 3000,
        savingsBudget: 2000,
        needsSpent: 2450.30,
        wantsSpent: 1820.50,
        savingsActual: 2100,
        needsRatio: 50,
        wantsRatio: 30,
        savingsRatio: 20,
        isCustom: false,
        createdAt: Date(),
        updatedAt: Date()
    )
    
    // MARK: - User Profile
    static let userProfile = UserProfile(
        profileId: "mock-profile-id",
        userId: "mock-user-id",
        monthlyIncome: 10000,
        currentNetWorth: 200000,
        currentMonthlyExpenses: 5000,
        currencyCode: "USD",
        timezone: "America/New_York",
        onboardingCompleted: true,
        onboardingStep: 5,
        createdAt: Date(),
        updatedAt: Date()
    )
    
    // MARK: - Net Worth Summary
    static let netWorthSummary = NetWorthSummary(
        totalNetWorth: 208240,
        previousNetWorth: 200000,
        growthAmount: 8240,
        growthPercentage: 4.12,
        asOfDate: "2026-02-05",
        breakdown: NetWorthBreakdown(
            assets: 250000,
            liabilities: 41760
        ),
        accounts: [
            Account(
                accountId: "mock-account-1",
                name: "Fidelity 401(k)",
                type: "investment",
                balance: 150000,
                institution: "Fidelity"
            ),
            Account(
                accountId: "mock-account-2",
                name: "Chase Checking",
                type: "cash",
                balance: 25000,
                institution: "Chase"
            )
        ]
    )
}
```

---

## `GET /get-spending-summary`

**Edge Function：** `get-spending-summary`  
**Query 参数：**

| 参数 | 必填 | 说明 |
|------|------|------|
| `month` | 否 | `YYYY-MM`，默认当前月 |

**成功时 `data` 结构（snake_case，iOS 经 `convertFromSnakeCase` 解码）：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `month` | string | 目标月 `YYYY-MM` |
| `total_spending` | number | needs + wants 支出合计 |
| `total_income` | number | 当月 `flamora_category === income` 的 \|amount\| 合计 |
| `needs` | object | `total`, `percentage`, `budget`, `remaining`, `over_budget`, `subcategories[]` |
| `wants` | object | 同上 |
| `savings` | object | `budget`（当月预算中的储蓄目标，可能为 null） |

`subcategories[]` 每项：`subcategory`, `amount`, `percentage`（占 `total_spending` 的比例）。

---

## `GET /get-transactions`

**Edge Function：** `get-transactions`  
**Query 参数：**

| 参数 | 必填 | 说明 |
|------|------|------|
| `page` | 否 | 默认 `1` |
| `limit` | 否 | 默认 `50`，最大 `100` |
| `category` | 否 | `needs` / `wants` / `income` / `transfer` → 过滤 `flamora_category` |
| `subcategory` | 否 | 过滤 `flamora_subcategory` |
| `start_date` | 否 | `YYYY-MM-DD` |
| `end_date` | 否 | `YYYY-MM-DD` |
| `pending_review` | 否 | `true` / `false` |
| `search` | 否 | 对 `merchant_name`、`name` 的 ilike |

**成功时 `data` 结构：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `transactions` | array | `transactions` 表行（`select('*')`），含 `plaid_account_id` 等列 |
| `pagination` | object | `page`, `limit`, `total`, `total_pages`, `has_more` |
| `pending_review_count` | number | 当前用户待审核笔数 |

**交易行与 iOS `APITransaction` 对齐字段示例：** `id`, `merchant_name`, `name`, `amount`, `date`, `pending_review`, `flamora_category`, `flamora_subcategory`, `plaid_account_id`（与 `plaid_accounts.id` 对应）。

---

## ✅ API 状态追踪

| API 端点 | 状态 | 负责人 | 完成日期 |
|---------|------|--------|----------|
| `POST /calculate-fire-goal` | ✅ 已完成 | 后端 | 2026-02-05 |
| `POST /save-fire-goal` | ✅ 已完成 | 后端 | 2026-02-05 |
| `POST /generate-monthly-budget` | ✅ 已完成 | 后端 | 2026-02-05 |
| `GET /active-fire-goal` | ✅ 已完成 | 后端 | 2026-02-06 |
| `GET /monthly-budget` | ✅ 已完成 | 后端 | 2026-02-06 |
| `GET /user-profile` | ✅ 已完成 | 后端 | 2026-02-06 |
| `GET /net-worth-summary` | ✅ 已完成 | 后端 | 2026-02-06 |
| `GET /get-spending-summary` | ✅ 已完成 | 后端 | 2026-03 |
| `GET /get-transactions` | ✅ 已完成 | 后端 | 2026-03 |
| `POST /create-user-profile` | ⬜ 待开发 | 后端 | Week 4 |

---

## ✅ API 状态

| API | 状态 | 开发模式 | 完成日期 |
|-----|------|----------|----------|
| `POST /create-user-profile` | ✅ 已完成 | ✅ 支持 | 2026-02-10 |

### 开发模式说明

**当前所有 API 都运行在开发模式：**
- ✅ 使用固定测试用户 ID: `00000000-0000-0000-0000-000000000001`
- ✅ 只需要 Anon Key，不需要真实用户 token
- ✅ 方便前端开发和测试

**上线前需要：**
- 将所有 API 的 `DEV_MODE` 改为 `false`
- 启用真实的 Supabase Auth 验证


## 📞 联系方式

**有问题？** 
- 后端：[你的联系方式]
- 前端：[Partner 联系方式]
- 文档更新：随时在此文档顶部标注版本号

**最后更新：** 2026-02-05 by 后端开发者