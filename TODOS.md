# Meridian — TODOS

Maintained by /plan-ceo-review. Last updated: 2026-04-07.

---

## P1 — Launch Blockers (from prior CEO review)

- [ ] **Privacy/Terms URL live check** — final public `/privacy` and `/terms` URLs must resolve before App Store submission. Dead links are an App Store rejection reason.
- [ ] **Push notification entitlements** — APNs entitlements must be set in Xcode project before OB step 16 can send real notifications.
- [ ] **OB step 16 (notification permission)** — onboarding notification permission screen not yet implemented.
- [ ] **Supabase APNs token column migration** — `push_token` column needed for push delivery.
- [ ] **stash@{1} resolve** — "本地合并冲突修复" stash needs investigation and resolution before main merge.
- [ ] **AppConfig fatalError → assertionFailure** — `AppConfig.required(_:)` calls `fatalError()` in production. Should be `assertionFailure()` with graceful fallback in non-DEBUG builds to avoid crashes in TestFlight.

---

## P1 — Home/Plan Rebuild Phase 2–6 (from 2026-04-07 CEO review)

- [ ] **JourneyView setupState 缓存** — `getSetupState()` 失败时回退使用 `@AppStorage` 缓存的上次 setupState，避免已设目标用户看到 "Set your FIRE goal" CTA。文件: `JourneyView.swift:107–109`。方案：将 setupState 序列化后存入 AppStorage，失败时读缓存。

- [ ] **applySelectedPlan 后 Home 刷新** — BudgetSetupView dismiss 时通知 JourneyView 刷新 setupState，避免用户 apply 计划后仍看到 "Choose a plan" CTA。文件: `BudgetSetupView.swift` dismiss callback + `JourneyView` refresh trigger。

- [ ] **BS_ChoosePathView Reality Check Card** — 当 `generate-plans` 的三条路径均超过合理年限（建议 >60 年），显示 Reality Check Card："基于你当前的净资产和收入，FIRE 在当前假设下需要超过 40 年。你可以调整退休花销目标，或先看 Simulator。" 两个 CTA：返回修改目标 / 打开 Simulator。文件: `BS_ChoosePathView.swift`。后端 `feasibility` 字段已可用。

- [ ] **BS_DiagnosisView 空数据状态** — 当 Plaid 账号没有足够交易历史（`generate-financial-diagnosis` 返回 $0 收入），Snapshot 页面显示专用空状态："我们还没有足够的交易记录。连接有至少 2 个月账单的账户，或手动输入月收入。" 两个 CTA：添加账户 / 手动输入。文件: `BS_DiagnosisView.swift`。

- [ ] **Apply Plan 触觉反馈 + count-up 动画** — 用户点击"使用这个计划"成功后：`UIImpactFeedbackGenerator(.medium)` 轻震 + FIRE 日期数字从旧值 count-up 到新值（SwiftUI `.animation` + 数字递增）。文件: `BS_ConfirmView.swift` apply 成功回调。

---

## P2 — Home Rebuild Unconnected State (from 2026-04-08 CEO review)

- [ ] **Unconnected state analytics 埋点** — 在 3 个 tab 的 unconnected state View 里加 analytics 事件（viewAppear、停留时长、CTA 点击）。数据能告诉你用户在 unconnected state 看了什么、停留多久，指导后续迭代方向。工作量 S。涉及文件：新建的 UnconnectedHomeView、UnconnectedCashflowView、UnconnectedInvestmentView。前提：Home Rebuild Phase 1 完成。P2。

- [ ] **Unconnected → Connected 状态切换动画** — 用户完成账户绑定后，3 个 tab 从 unconnected view 切换到 connected view 目前是 direct cut（无动画）。需要设计每个 tab 的最佳入场过渡（可能是淡入、slide 或 matched geometry）。工作量 M。涉及文件：JourneyView.swift、CashflowView.swift、InvestmentView.swift 的 `hasLinkedBank` gate 处。前提：Home Rebuild Phase 1 完成 + Design 确认过渡方案。P2。

---

## P2 — v2 Features (post-launch)

- [ ] **Initial Financial Snapshot ("Issue Zero")** — APPROVED for v2. Triggered immediately when user connects their first bank account. Shows: spending trends for available months, income overview, investment growth rate vs 7% benchmark. Ends with teaser: "Starting next month, you'll receive monthly FIRE reports + an annual summary." Same Edge Function as monthly report, different trigger. Prerequisite for monthly report build.

- [ ] **Monthly FIRE Progress Report** — APPROVED for v2. Build: Supabase Edge Function `generate-monthly-report` (aggregates transactions, computes FIRE date delta, calls Groq/Haiku for AI insight), Supabase `monthly_reports` table, iOS `MonthlyReportView.swift`. Trigger: pg_cron on 1st of month + APNs push. See CEO plan `2026-04-06-monthly-fire-report.md` for full spec.

- [ ] **Annual FIRE Wrapped** — APPROVED for v2. Same data as monthly report, yearly window. Hero metric: FIRE date change over the year. Shareable image via SwiftUI `ImageRenderer` (iOS 16+). Show partial year for users < 12 months. Bundle with monthly report build.

- [ ] **Simulator 分享功能** — Simulator 结果页加「分享这个场景」按钮，用 SwiftUI `ImageRenderer` 生成一张包含 FIRE 日期、delta、当前 vs 调整路径图表的分享图。增长渠道——用户把 FIRE 场景发给朋友是口碑传播。技术风险：ImageRenderer 在 iOS 16+，需真机测试渲染效果（模拟器渲染与真机有差异）。文件: `SimulatorView.swift`。先决条件：Phase 4 Simulator 重建完成。P2。

- [ ] **FIRE date backend precision** — `yearsRemaining: Int` is whole years only. Edge Function `get-active-fire-goal` should return `estimated_fire_date` (ISO 8601) or `months_remaining: Int`. `APIFireGoal` model needs new field. `FIRECountdownCard.fireDateLabel()` updates to use precise value. Required before FIRE date delta in monthly report is accurate.

- [ ] **Static FIRE case studies content** — Curated FIRE success stories (no UGC, editorially selected). Confirm content source and format before building the Inspiration Tab. Prerequisite for community tab. P2.

- [ ] **Coast/Barista/Fat FIRE scenario modeling** — deferred from v1. Add FIRE variant selector in Settings + updated projection logic. P2.

---

## P3 — v3 Features (after user scale)

- [ ] **Community UGC Tab** — 3rd tab accepting user posts, FIRE milestone sharing, comments/discussion. Prerequisites: 500+ real users (content seeding solved), moderation tooling, UGC backend (posts table, likes, reports). Do not start before user base is established. P3.

- [ ] **Navigation restructure** — Collapse 3 tabs (Home, Cash Flow, Investment) into 2, free up 3rd tab for Community. Prerequisite: Community tab is ready. Decide merge direction (Home+Investment or Cashflow+Investment) at that time. P3.

- [ ] **Android** — Post iOS-validated retention metrics. P3.

---

## Deferred — Decided Against (not roadmap)

- Push notification A/B testing — post-launch operational item, not a build item.
