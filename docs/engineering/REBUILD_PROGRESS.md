# Flamora Rebuild — Execution Log

> Started: 2026-04-14  
> Reference: `docs/engineering/REBUILD_TODO.md`

---

## S-ASSUMPTIONS — ✅ 完成

**目标**：建立前后端统一财务假设常量，消灭三处 hardcode return rate。

**改动文件**：
| 文件 | 类型 | 改动 |
|------|------|------|
| `Fire cursor/supabase/functions/_shared/fire-assumptions.ts` | 新建 | 单一来源：NOMINAL 0.07 / REAL 0.04 / WITHDRAWAL 0.04 / INFLATION 0.03 |
| `Fire cursor/supabase/functions/_shared/fire-calculator.ts` | 修改 | `ANNUAL_RETURN = 0.08` → `ASSUMPTIONS.REAL_ANNUAL_RETURN`；`WITHDRAWAL_RATE = 0.04` → `ASSUMPTIONS.WITHDRAWAL_RATE` |
| `Fire cursor/supabase/functions/_shared/fire-math.ts` | 修改 | `computeFireDate` 默认 `0.07` → `ASSUMPTIONS.REAL_ANNUAL_RETURN`；`computeFireNumber` 默认 `0.04` → `ASSUMPTIONS.WITHDRAWAL_RATE` |
| `Fire cursor/supabase/functions/generate-plans/index.ts` | 修改 | 本地 `NOMINAL=0.08 / REAL=0.055 / INFLATION=0.025` → 从 `ASSUMPTIONS` 导入 |
| `Models/FIREAssumptions.swift` | 新建 | iOS 镜像常量（需手动加入 Xcode project） |
| `View/Journey/SimulatorView.swift` | 修改 | 初始化 fallback `?? 0.07` / `?? 0.04` → `FIREAssumptions.nominalAnnualReturn` / `FIREAssumptions.withdrawalRate` |

**验证结果**：
- `grep 0.08|0.055` 在 `_shared/fire-calculator.ts`、`fire-math.ts`、`generate-plans/index.ts` → 空 ✅
- `grep "?? 0.07\|?? 0.04"` 在 `SimulatorView.swift` → 空 ✅
- 新文件 `fire-assumptions.ts` / `FIREAssumptions.swift` 内容与文档定义一致 ✅

**风险说明**：
- `FIREAssumptions.swift` 需手动添加到 Xcode project（`.pbxproj`），否则编译时找不到。
- `OnboardingData.swift` 里有 `accumulated * 1.09`（9% onboarding 快速估算）。文档未将其列入 S-ASSUMPTIONS 范围（9% 不在 grep 目标列表内），本轮不改，留待 Onboarding 重构。
- 服务端 `REAL_ANNUAL_RETURN` 从 0.055 降到 0.04，对 Step 4/5 的 required savings 计算会产生实质影响（更保守 → required contribution 变高）。这是文档有意为之的修正，不是 bug。

---

---

## S0-1 — ✅ 完成

**目标**：修复 `saveBudgetEdit()` ratio 归一 bug，消除后端 INVALID_RATIOS 400。

**改动文件**：
| 文件 | 改动 |
|------|------|
| `View/Cashflow/CashflowView.swift` | 删除 `ratioSum` 归一逻辑；改为从 `needsBudget / wantsBudget / savingsBudget` 绝对金额重算三个 ratio |

**验证结果**：
- `ratioSum` 变量已消失 ✅
- `apiBudget.savingsBudget` 字段存在于 `APIMonthlyBudget`（`mockdata.swift:818`）✅
- 数学验证：`needs+wants+savings = totalBudget` → 三 ratio 之和恒等于 100 ✅
- 旧代码中 `savings_ratio` 会在 ratio 归一后叠加，导致 total ≈ 120；新代码不会 ✅

**风险说明**：
- 运行验证需在 simulator 手动触发 Budget 编辑保存，观察后端是否不再返回 400。无法在本地自动测试。
- `totalBudget == 0` 边界：若 needs+wants+savings 均为 0，不写入 ratio（保留 dict 初始值）。这是极端 degenerate 情况，实际不会发生。

---

---

## S-ASSUMPTIONS 补完 — ✅ 完成

**目标**：修复 S-ASSUMPTIONS 遗漏项（pbxproj、PMT hardcode、后端遗漏 endpoints）。

**改动文件**：
| 文件 | 改动 |
|------|------|
| `Flamora app.xcodeproj/project.pbxproj` | 新增 `FIREAssumptions.swift` 到 Models 组 + app target Sources（GUIDs: `CD11E0072F90`, `CD11E0082F90`） |
| `View/BudgetSetup/BudgetSetupViewModel.swift` | `0.055 / 12` → `FIREAssumptions.realAnnualReturn / 12` |
| `Fire cursor/supabase/functions/save-fire-goal/index.ts` | 导入 `ASSUMPTIONS`；`DEFAULT_WITHDRAWAL_RATE/INFLATION/RETURN_RATE` 改用 `ASSUMPTIONS.*` |
| `Fire cursor/supabase/functions/get-active-fire-goal/index.ts` | 导入 `fire-math.ts` + `fire-assumptions.ts`；删除本地 `computeFireDate/computeFireNumber/getProgressStatus` 重复实现；`?? 0.07` / `?? 0.04` 改用 `ASSUMPTIONS.*` |
| `Fire cursor/supabase/functions/preview-simulator/index.ts` | 导入 `ASSUMPTIONS`；`DEFAULT_RETURN_RATE=0.07` → `NOMINAL`，`DEFAULT_WITHDRAWAL=0.04` → `WITHDRAWAL_RATE` |
| `Fire cursor/supabase/functions/create-user-profile/index.ts` | 导入 `ASSUMPTIONS`；两处 `annualReturn = 0.08` → `ASSUMPTIONS.REAL_ANNUAL_RETURN` |

**验证结果**：
- `xcodebuild` → **BUILD SUCCEEDED** ✅
- grep `0.07/0.08/0.055` 在所有改动文件 → 空 ✅
- `FIREAssumptions` SourceKit 警告消失（build 期间解析成功） ✅

---

## S0-2 — ✅ 完成（待 supabase db push）

**目标**：打通 `category_budgets` 完整读写链路（migration + 后端 + iOS key 规范化）。

**改动文件**：
| 文件 | 类型 | 改动 |
|------|------|------|
| `Fire cursor/supabase/migrations/20260414_add_category_budgets.sql` | 新建 | `ALTER TABLE budgets ADD COLUMN IF NOT EXISTS category_budgets JSONB DEFAULT '{}'` |
| `Fire cursor/supabase/functions/generate-monthly-budget/index.ts` | 修改 | interface + upsert payload + response 加 `category_budgets` |
| `Fire cursor/supabase/functions/get-monthly-budget/index.ts` | 修改 | response 加 `category_budgets` |

**已部署函数**：
- S-ASSUMPTIONS 补完：`generate-plans` / `save-fire-goal` / `get-active-fire-goal` / `preview-simulator` / `create-user-profile` ✅
- S0-2：`generate-monthly-budget` / `get-monthly-budget` ✅

**待用户执行**：`supabase db push` 推送 migration（函数已部署，DB 列未建前写入会静默忽略）。

---

## S0-2a — ✅ 完成

**目标**：统一 iOS 侧 `category_budgets` key 为 canonical id，修复读路径 id/展示名混用问题。

**改动文件**：
| 文件 | 改动 |
|------|------|
| `Models/TransactionCategoryCatalog.swift` | 新增 `id(forDisplayedSubcategory:)` helper |
| `View/Cashflow/BudgetCard.swift` L811–814 | 写入时 key 改为 `TransactionCategoryCatalog.id(forDisplayedSubcategory:) ?? item.name` |
| `View/Cashflow/CashflowView.swift` L291–342 | 读路径：`budgetMap.keys`（id）先映射为展示名再合并 orderedNames；金额回查用 id |

**验证点**：
- 保存 Budget → DB `category_budgets` key 全部是 catalog id（如 `"groceries"`，非 `"Groceries"`）
- 重新打开 Cash Flow → BudgetCard 正确显示用户设定金额
- TransactionCategoryCatalog 里改 name → 预算金额仍正确对上（id 不变）

---

## S1-1 + S1-1a — ✅ 完成

**目标**：`target_retirement_age` 成为 Goal Setup 必填字段；老用户/多设备自动回填。

**改动文件**：
| 文件 | 改动 |
|------|------|
| `View/BudgetSetup/BS_GoalSetupView.swift` | 新增 `retirementAgeCard`（+/− 步进器，范围 currentAge+5~75）；`fireNumberPreview` 新增 PMT 估算行；CTA disabled 条件加 `targetRetirementAge <= 0`；`onChange` 同步 spendingText（async 回填后刷新） |
| `View/BudgetSetup/BudgetSetupViewModel.swift` | 新增 `var targetRetirementAge: Int = 0`；`saveFireGoal()` 传 `targetRetirementAge` + `currentAge`；新增 `restoreFromActiveFireGoal()`；`loadInitialData()` 调用它 |

**后端改动**：无（`get-active-fire-goal` 已返回 `target_retirement_age` + `retirement_spending_monthly`；`save-fire-goal` 已接受 `target_retirement_age` optional）

**关键决策**：
- PMT 计算用 `FIREAssumptions.realAnnualReturn`（可行性判定，不用 nominal）
- 步进器首次 `+` 跳到 `currentAge + 5`（或 30 若 age 未加载）
- `restoreFromActiveFireGoal()` 只覆盖非零值（不清除用户当前输入）

**验收**：
- [ ] 新用户：spending + age 都填才能点 Continue
- [ ] 选完 age 后 preview 卡片出现 PMT 行（real-time 动画）
- [ ] 老用户重新打开 Budget Setup → spending + age 自动回填
- [ ] 老用户（`target_retirement_age = NULL`）打开 Budget Setup → 被拦回 Goal Setup 并显示提示文案
- [ ] Journey Hero 对 `targetRetirementAge == nil` 的用户显示 "Complete goal setup" CTA

**S1-1a 补完（2026-04-14）**：

| 文件 | 改动 |
|------|------|
| `View/BudgetSetup/BudgetSetupViewModel.swift` | `resumeFromSetupState()` 开头先调 `restoreFromActiveFireGoal()`；若 goal 存在但 `targetRetirementAge == 0` → 强制 `currentStep = .goalSetup` + `goalSaveError` 提示文案 |
| `View/Journey/FIRECountdownCard.swift` | 新增 `incompleteGoalState` view；body dispatch 在 `hero != nil` 分支增加 `targetRetirementAge` 判断：nil/0 → `incompleteGoalState`，否则 → `loadedState` |

**Build 验证**：`xcodebuild` → **BUILD SUCCEEDED** ✅

---

## 待执行

下一步：**S1-2** — BS_ChoosePathView 三段式 Plan 卡片（steady / recommended / accelerate）。
