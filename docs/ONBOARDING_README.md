# Flamora Onboarding 流程说明（V1 + V2 合并文档）

一份文件看懂两套 Onboarding：当前谁在用、步骤对照、数据与文件结构。

---

## 一、当前使用哪套

| 项目 | 说明 |
|------|------|
| **入口** | `ContentView` 未完成引导时显示 **OB_ContainerView** |
| **完成条件** | `isOnboardingComplete && hasCompletedOnboarding` 才进主界面 |
| **V1** | `OnboardingContainerView` 当前未被 ContentView 引用，仅保留；`hasCompletedOnboarding` 仍用于「老用户已走完 V1」时跳过引导 |

---

## 二、共享数据模型（无重复）

两套流程共用 **同一份** `OnboardingData`，路径：

- `Services/OnboardingData.swift`

### 主要字段

| 字段 | 含义 |
|------|------|
| email, userId, userName | 登录与身份 |
| motivations | 动机多选（Set<String>） |
| age, country, currencyCode, currencySymbol | 年龄与地区/货币 |
| monthlyIncome, monthlyExpenses, currentNetWorth | 收入/支出/净资产 |
| fireType, targetMonthlySpend | FIRE 类型与目标月支出 |
| selectedPlan | 订阅 "monthly" / "yearly" |
| plaidConnected | 是否已连 Plaid |
| painPoint | V2 用：痛点单选（pain_money_tracking / pain_saving / pain_investing / pain_fire） |

### 计算属性（部分）

- savingsRate, monthlySavings, fireNumber, yearsToFire, freedomAge  
- V2 扩展：suggestedExtraInvestment, optimizedFreedomAge, yearsSaved, delayPenalty, fireProgress, userSituation  

同文件还定义：`UserSituation`、`MotivationOption`、`motivationOptions`、`CurrencyOption`、`currencyOptions`。

---

## 三、Onboarding V1（12 步）

- **容器**: `View/Onboarding/OnboardingContainerView.swift`
- **持久化**: `@AppStorage("hasCompletedOnboarding")`
- **进度条**: 步骤 2–9 显示 `OnboardingProgressBar`（8 格）

### 步骤与视图对照

| 步骤 | 视图文件 | 说明 |
|------|----------|------|
| 0 | OB_WelcomeView | 欢迎 / 价值主张 |
| 1 | OB_SignInView | 邮箱登录/注册 |
| 2 | OB_NameView | 姓名 |
| 3 | OB_MotivationView | 动机多选 |
| 4 | OB_AgeLocationView | 年龄与地区 |
| 5 | OB_IncomeView | 月收入 |
| 6 | OB_ExpensesView | 月支出 |
| 7 | OB_NetWorthView | 净资产 |
| 8 | OB_LifestyleView | 生活方式 |
| 9 | OB_BlueprintView | FIRE 蓝图确认 |
| 10 | OB_PaywallView | 付费墙 |
| 11 | OB_PlaidLinkView | 银行连接（完成或跳过即完成 Onboarding） |

### V1 视图文件列表（同一目录）

- OnboardingData.swift  
- OnboardingContainerView.swift  
- OB_WelcomeView, OB_SignInView, OB_NameView, OB_MotivationView  
- OB_AgeLocationView, OB_IncomeView, OB_ExpensesView, OB_NetWorthView  
- OB_LifestyleView, OB_BlueprintView, OB_PaywallView, OB_PlaidLinkView  
- OB_SuccessView（容器中未使用，可能为遗留）

---

## 四、Onboarding V2（18 步）

- **容器**: `View/Onboarding/OB_ContainerView.swift`
- **持久化**: `@AppStorage("hasCompletedOnboardingV2")`（保留 key 以兼容已完程用户）
- **特殊逻辑**: 若已登录且未完成 V2，`onAppear` 时跳到 step 3（Intro），并预填 userId / email

### 步骤与视图对照

| 步骤 | 视图文件 | 说明 |
|------|----------|------|
| 0 | OB_SplashView | 动效 Splash |
| 1 | OB_WelcomeView | 欢迎轮播（4 页） |
| 2 | OB_SignInView | 登录/注册 |
| 3 | OB_IntroView | “Let’s build your freedom plan” |
| 4 | OB_NameView | 姓名 |
| 5 | OB_MotivationView | 动机多选 |
| 6 | OB_SocialProofView | 社会认同过渡 |
| 7 | OB_PainPointsView | 痛点单选 |
| 8 | OB_ValueScreenView | 动态价值页（依 painPoint） |
| 9 | OB_AgeView | 年龄与货币（Snapshot 1/5） |
| 10 | OB_IncomeView | 月收入（Snapshot 2/5） |
| 11 | OB_SpendingView | 月支出（Snapshot 3/5） |
| 12 | OB_InvestmentView | 投资组合（Snapshot 4/5） |
| 13 | OB_LifestyleView | 退休生活方式（Snapshot 5/5） |
| 14 | OB_LoadingView | 加载/计算动效 |
| 15 | OB_RoadmapView | FIRE 路线图（核心转化） |
| 16 | OB_AhaMomentView | Aha 时刻 / 盲区 |
| 17 | OB_PaywallView | 付费墙（完成即 completeOnboarding） |

V2 无单独 Plaid 步骤；Paywall 完成后直接 `completeOnboarding()`，主流程结束。

### V2 文件结构

- **容器**: `OB_ContainerView.swift`  
- **Views/**  
  OB_SplashView, OB_WelcomeView, OB_SignInView, OB_IntroView, OB_NameView, OB_MotivationView, OB_SocialProofView, OB_PainPointsView, OB_ValueScreenView, OB_AgeView, OB_IncomeView, OB_SpendingView, OB_InvestmentView, OB_LifestyleView, OB_LoadingView, OB_RoadmapView, OB_AhaMomentView, OB_PaywallView  
- **Components/**  
  OB_BackButton, OB_PrimaryButton, OB_SelectionCard, OB_MicroInsightCard, OB_IncomeSlider, OB_SnapshotProgress, OB_PersonalizeProgress  

---

## 五、步骤含义对照（去重对照）

| 含义 | V1 步骤 | V2 步骤 |
|------|---------|---------|
| 欢迎/价值 | 0 Welcome | 1 Welcome（0 为 Splash） |
| 登录/注册 | 1 SignIn | 2 SignIn |
|  intro | — | 3 Intro |
| 姓名 | 2 Name | 4 Name |
| 动机 | 3 Motivation | 5 Motivation |
| 社会认同/痛点 | — | 6 SocialProof, 7 PainPoints, 8 ValueScreen |
| 年龄与地区/货币 | 4 AgeLocation | 9 Age |
| 收入 | 5 Income | 10 Income |
| 支出 | 6 Expenses | 11 Spending |
| 净资产 | 7 NetWorth | —（V2 用 Investment 等 Snapshot） |
| 投资/财务快照 | — | 12 Investment |
| 生活方式 | 8 Lifestyle | 13 Lifestyle |
| 蓝图/结果 | 9 Blueprint | 14 Loading → 15 Roadmap → 16 AhaMoment |
| 付费墙 | 10 Paywall | 17 Paywall |
| 银行连接 | 11 PlaidLink | 无（Paywall 后即完成） |

---

## 六、ContentView 逻辑摘要

- **显示主界面条件**: `isOnboardingComplete && hasCompletedOnboarding`  
- **未完成引导时**: 只显示 `OB_ContainerView`。  
- **checkExistingSession**: 若 `supabase.isAuthenticated && hasCompletedOnboarding`，也会设 `isOnboardingComplete = true`，供老用户直接进主界面。  
- **登出**: `isAuthenticated` 变 false 时，`isOnboardingComplete = false`，`hasCompletedOnboarding = false`，回到引导。

---

## 七、持久化标记小结

| Key | 含义 |
|-----|------|
| hasCompletedOnboarding | V1 全流程完成（含 Paywall + PlaidLink 完成或跳过） |
| hasCompletedOnboardingV2 | 全流程完成（AppStorage key 保留兼容）（到 Paywall 并点击完成） |

两套标记并存，便于兼容旧用户；新流程以 V2 为准。

---

*文档合并自 Onboarding 与 Onboarding V2，避免重复说明，一文件概览两套流程。*
