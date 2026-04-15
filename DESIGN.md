# Design System — Flamora (Current App Baseline)

## Product Context
- **What this is:** FIRE-focused personal finance app (Home, Cash Flow, Investment).
- **Who it's for:** People tracking spending, savings, and asset growth with low-friction daily checks.
- **Platform:** iOS SwiftUI.
- **Source of truth:** Existing shipped `Home + Cash Flow + Investment` visual language.

## North Star
Flamora is a **light-shell system** with a **dark atmospheric hero** and **glass-like content cards**.

The app should feel:
- focused and premium
- financial, but not cold
- structured, with clear hierarchy and minimal visual noise

## Foundations

### 1) Surface Model
- **Top hero region:** dark brand gradient + glow (`heroBrandLinearGradient`, investment uses `investBrandLinearGradient`).
- **Main shell region:** soft light gradient (`shellBg1` -> `shellBg2`).
- **Cards in shell:** light glass cards, not dark slabs.
- **Dark surfaces (`surface`, `backgroundPrimary`)** are legacy/detail-only contexts, not default for top-level tab content.

### 2) Text Model
- On light/glass surfaces use `inkPrimary`, `inkSoft`, `inkFaint`, `inkMeta`.
- On dark hero/fullscreen overlays use `textPrimary`, `textSecondary`, `textTertiary`.
- Never mix white text into light cards except tiny intentional badge chips.

### 2a) Dual Color Token Clarification
The codebase has two coexisting token groups. Use them in the right context:

| Token group | Tokens | Use when |
|---|---|---|
| Legacy dark tokens | `textPrimary` (#FFF), `backgroundPrimary` (#000), `surface` | Dark hero zone, fullscreen overlays, OB_WelcomeView |
| Current light tokens | `inkPrimary` (#111827), `shellBg1` (#F7F8FB), `shellBg2` | Shell body, all light-bg OB steps, cards |

Do not use `textPrimary` (white) on light/shellBg backgrounds — it disappears.
Do not use `inkPrimary` (near-black) on dark hero areas — it clashes.

### 3) Color Semantics
- `Needs` = blue family.
- `Wants` = purple family for budget/category context in Cash Flow cards.
- positive state = `success` / green.
- warning state = `warning`.
- negative/over-budget = `error`.

### 4) Typography
- Keep current token system in `Style/Typography.swift`.
- Headline emphasis comes from weight + spacing, not decorative fonts.
- Card labels should stay compact and uppercase where already used (`cardHeader` + tracking token).

### 5) Spacing + Radius
- Keep current semantic scale in `Style/Spacing.swift`.
- Keep radius system in `AppRadius`.
- Card families should remain consistent:
  - main glass card around `glassCard/glassPanel` feel
  - nested sub-panels as softer inset blocks (`glassBlock` feel)

## Layout Architecture (By Tab)

### Shared Shell Structure
1. Hero copy zone (top, dark atmospheric)
2. White/light bottom sheet body
3. Vertical card stack inside sheet
4. Floating glass tab bar
5. Tab bar must use fixed light-glass tokens (`tabBarFill`, `tabBarBorder`, `tabBarShadow`) and must not rely on adaptive material that can turn dark.

### Home Tab
- Primary block: roadmap-style progression card.
- Secondary pattern: clear next actions with directional affordance.
- Tone: onboarding-like clarity without marketing copy bloat.

### Cash Flow Tab
- Connected state shows real cards: Income, Saving Rate, Budget, Cash Accounts, Transactions.
- Unconnected state can show prototype/CTA.
- **Rule:** once bank is connected, do not show the old “Spending overview + Connect accounts” placeholder block.

### Investment Tab
- Card stack: Portfolio performance, Allocation, Accounts.
- Same shell/card language as Cash Flow, with cooler hero gradient variant.
- Data-heavy cards remain readable first, decorative second.

## Onboarding Design Rules

Onboarding steps are split into two visual zones. Each step must belong to one zone only.

### Zone A — Dark Atmospheric (Welcome only)
- **Applies to:** `OB_WelcomeView`
- Background: `Image("AppBackground")` (dark photo)
- Text tokens: `textPrimary`, `textSecondary` (white family)
- Fire gradient can appear on dark bg for brand moments (logo, highlights)
- Button: standard white-fill CTA on dark bg

### Zone B — Light Shell (all other OB steps)
- **Applies to:** `OB_GoalSetupView`, `OB_IncomeView`, `OB_SpendingView`, `OB_RoadmapView`, `OB_ValueScreenView`, and all other steps
- Background: `shellBg1` → `shellBg2` gradient (soft off-white)
- Text tokens: `inkPrimary`, `inkSoft`, `inkFaint`
- Button: standard white-fill CTA (`AppColors.surface` background, `inkPrimary` text)

### Slider Rule (Zone B only)
- `UISlider.appearance().thumbTintColor` must be a visible color on light bg
- Use `uiSliderThumbTint` token (defined in `Style/Colors.swift`)
- Token value must be brand purple `#A78BFA` — NOT white (`UIColor(1,1,1,1)`)
- White thumb on shellBg = invisible. This is a P1 visual bug.

### Fire Gradient on Light Background
- `gradientStart` (#A78BFA, purple) — safe to use as accent on shellBg
- `gradientMiddle` (#FCA5A5, light pink) — near-invisible on white, avoid for text
- `gradientEnd` (#FCD34D, gold) — near-invisible on white, avoid for text
- Rule: on Zone B, only use `gradientStart` for fire gradient accents. If the design calls for a gold/pink moment, use an icon or illustration, not raw gradient color on text.

### OB Step Background Switching
- The switch happens once: Welcome (Zone A) → everything else (Zone B)
- There is no back-and-forth between dark and light within the OB flow
- If a new OB step is added, default to Zone B unless it is a full-screen brand splash

## Component Standards

### Budget Card (Critical)
- Must stay in-card for edit mode (same footprint, no card resize jump).
- Ring is full circle with 12 o'clock start.
- Scope switch supports `All / Needs / Wants`.
- Budget card itself is **light glass** in shell context, not dark slab.
- Needs and Wants must use **light blue / light purple background families** consistently.
- Over-budget visual appears only when `spent / budget > 1.0`.
- Over-budget style: full ring + red overrun indicator + explicit copy (`Over budget by $X`).
- Edit state is in-place, never a separate route for this interaction.

#### Budget Color Spec (Light Style, Required)
- `Needs` stroke/active: `#6AABF7`
- `Needs` soft background: `#EAF0FF`
- `Wants` stroke/active: `#A58AF1`
- `Wants` soft background: `#F3EEFF`
- Ring track on light card: ink-based low alpha (not dark gray slab)
- Text on budget card: `inkPrimary / inkSoft`, avoid white text except tiny badges

#### Budget Don'ts
- Do not render Budget card with `surface`-style dark background in Home/Cash Flow shell.
- Do not use teal/amber as primary Needs/Wants meaning in this card family.
- Do not use high-neon saturated purple that clashes with hero gradient family.

### Saving Rate Card (Critical)
- No linear progress bar.
- Visual metaphor is **check-in / punch-card** style (month-by-month marks).
- Saving Rate card itself is **light glass** in shell context, not dark panel.
- Core info trio:
  - manual saving amount
  - actual saving rate
  - status chip
- Status semantics:
  - `On track`
  - `At risk`
  - `Off track`
- Labels must be readable without relying on color only.

#### Saving Rate Light-Surface Rules
- Card background: same light/glass family as Budget card.
- Check-in dots/chips: subtle tinted fills on light background, not neon on black.
- Primary number and percentage use ink hierarchy (`inkPrimary` first).
- Status chips should be light-tint semantic chips:
  - On track: green tint background + dark green text
  - At risk: amber tint background + dark amber text
  - Off track: red tint background + dark red text

### Connection CTAs
- CTA only appears when data dependency is truly missing (not when account is already linked).
- Button language should be direct and action-first (`Connect accounts`, `Edit budget`, `Save`).

### Cards + Nested Blocks
- Top-level cards: light glass surface, subtle border, soft shadow.
- Nested blocks: lighter fill, tighter radius, clear separation.
- Avoid mixing unrelated card styles in the same scroll section.

## Interaction Patterns

### Motion
- Short, practical transitions.
- No constant decorative animation loops in primary finance cards.
- Animations should communicate state change (edit/display, loading/loaded, selected/unselected).

### Editing
- Prefer inline editing in context for high-frequency actions.
- Prevent invalid saves with explicit constraints and live diff hints.
- Disable primary action when constraints fail.

### State Clarity
- Connected vs unconnected must be visually and behaviorally distinct.
- Empty states should still match shell/card language.
- Error banners should be obvious but not break card rhythm.

## Copy Tone
- Direct and calm.
- Avoid hype or generic “smart finance” filler.
- UI labels should describe real user task, not internal model terms.

## Accessibility
- Minimum 44pt hit targets.
- Maintain readable contrast in light shell and dark hero contexts.
- Never communicate critical state by color alone.
- Keep numeric figures high-contrast and easy to scan.

## Do / Don't

### Do
- Use current light-shell hierarchy from Home/Cash Flow/Investment.
- Keep card sizes stable across state toggles.
- Keep Needs/Wants color mapping stable across chart, ring, and tags.
- Keep Saving Rate in check-in visual form.
- Keep Budget + Saving Rate as light cards in Cash Flow connected state.

### Don't
- Revert top-level pages to dark-first.
- Show connect-account placeholder blocks after accounts are linked.
- Use generic progress bars where check-in semantics are required.
- Introduce one-off accent colors that break semantic mapping.
- Use dark card backgrounds for Budget/Saving cards in the light shell area.

## QA Checklist (Before Ship)

### Main App
1. Is this screen visually in the same family as current Home/Cash Flow/Investment?
2. Is top-level shell light, with dark hero only in the intended zone?
3. In Cash Flow connected state, are placeholder “connect” blocks fully gone?
4. Does Budget card use full ring + `All/Needs/Wants` + fixed card footprint?
5. Are Needs/Wants using blue/purple background semantics?
6. Does Saving Rate use check-in form, not linear bar?
7. Does Saving Rate show amount + actual rate + status clearly?
8. Are invalid edit states blocked with explicit guidance?

### Onboarding
9. Is OB_WelcomeView the only step with a dark background?
10. Are all other OB steps using shellBg1/shellBg2?
11. Is the slider thumb visible on light backgrounds (not white-on-white)?
12. Is fire gradient only used on dark bg or via `gradientStart` (#A78BFA) on light bg?
13. Are all OB text labels using `inkPrimary`/`inkSoft`, not `textPrimary` (white)?

## Decisions Log
| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-04-13 | Move DESIGN baseline to light-shell-first | Match shipped Home/Cash Flow/Investment direction |
| 2026-04-13 | Promote full-system doc (not color-only) | Ensure future UI work follows section, state, and interaction patterns |
| 2026-04-13 | Needs/Wants semantic update to blue/purple backgrounds | Align budget visuals with current product direction and user instruction |
| 2026-04-14 | Budget + Saving Rate explicitly locked to light-surface style | Remove ambiguity that could reintroduce dark card styling in Cash Flow shell |
| 2026-04-14 | Tab bar locked to fixed light-glass tokens | Prevent regressions where adaptive material renders tab bar black in dark environments |
| 2026-04-14 | Onboarding split into Zone A (dark) / Zone B (light) | Welcome uses dark photo bg for brand impact; all other steps use shellBg for consistency with main app |
| 2026-04-14 | Slider thumb token must be brand purple, not white | White UISlider thumb is invisible on shellBg — P1 visual bug |
| 2026-04-14 | Fire gradient restricted on light backgrounds | gradientMiddle/gradientEnd are near-white; on light bg only gradientStart (#A78BFA) is safe |
| 2026-04-14 | Dual token system clarified in 2a | textPrimary/backgroundPrimary = dark zone only; inkPrimary/shellBg1 = light shell only |
