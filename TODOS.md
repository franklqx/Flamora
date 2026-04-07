# Flamora — TODOS

Maintained by /plan-ceo-review. Last updated: 2026-04-06.

---

## P1 — Launch Blockers (from prior CEO review)

- [ ] **Privacy/Terms URL live check** — flamora.app/privacy and /terms must resolve before App Store submission. Dead links are an App Store rejection reason.
- [ ] **Push notification entitlements** — APNs entitlements must be set in Xcode project before OB step 16 can send real notifications.
- [ ] **OB step 16 (notification permission)** — onboarding notification permission screen not yet implemented.
- [ ] **Supabase APNs token column migration** — `push_token` column needed for push delivery.
- [ ] **stash@{1} resolve** — "本地合并冲突修复" stash needs investigation and resolution before main merge.
- [ ] **AppConfig fatalError → assertionFailure** — `AppConfig.required(_:)` calls `fatalError()` in production. Should be `assertionFailure()` with graceful fallback in non-DEBUG builds to avoid crashes in TestFlight.

---

## P2 — v2 Features (post-launch)

- [ ] **Initial Financial Snapshot ("Issue Zero")** — APPROVED for v2. Triggered immediately when user connects their first bank account. Shows: spending trends for available months, income overview, investment growth rate vs 7% benchmark. Ends with teaser: "Starting next month, you'll receive monthly FIRE reports + an annual summary." Same Edge Function as monthly report, different trigger. Prerequisite for monthly report build.

- [ ] **Monthly FIRE Progress Report** — APPROVED for v2. Build: Supabase Edge Function `generate-monthly-report` (aggregates transactions, computes FIRE date delta, calls Groq/Haiku for AI insight), Supabase `monthly_reports` table, iOS `MonthlyReportView.swift`. Trigger: pg_cron on 1st of month + APNs push. See CEO plan `2026-04-06-monthly-fire-report.md` for full spec.

- [ ] **Annual FIRE Wrapped** — APPROVED for v2. Same data as monthly report, yearly window. Hero metric: FIRE date change over the year. Shareable image via SwiftUI `ImageRenderer` (iOS 16+). Show partial year for users < 12 months. Bundle with monthly report build.

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
