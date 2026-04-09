# Flamora Home Rebuild Implementation Spec

Date: 2026-04-09

Status: Draft implementation spec for the current unconnected-state prototype

Primary source of truth:
- HTML prototype (repo): `design-reference/home-rebuild-glass-prototype.html`

Project implementation targets:
- Main container: `/Users/staygreen/Documents/GitHub/Flamora/View/MainTabView.swift`
- Home shell: `/Users/staygreen/Documents/GitHub/Flamora/View/Journey/JourneyView.swift`
- Home hero candidate: `/Users/staygreen/Documents/GitHub/Flamora/View/Journey/FIRECountdownCard.swift`
- Home sandbox target: `/Users/staygreen/Documents/GitHub/Flamora/View/Journey/SimulatorView.swift`
- Cash Flow root: `/Users/staygreen/Documents/GitHub/Flamora/View/Cashflow/CashflowView.swift`
- Investment root: `/Users/staygreen/Documents/GitHub/Flamora/View/Investment/InvestmentView.swift`
- Existing Home support components:
  - `/Users/staygreen/Documents/GitHub/Flamora/View/Journey/ProgressBar.swift`
  - `/Users/staygreen/Documents/GitHub/Flamora/View/Journey/PortfolioCard.swift`
  - `/Users/staygreen/Documents/GitHub/Flamora/View/Journey/BudgetPlanCard.swift`
- Existing Cash Flow support components:
  - `/Users/staygreen/Documents/GitHub/Flamora/View/Cashflow/IncomeCard.swift`
  - `/Users/staygreen/Documents/GitHub/Flamora/View/Cashflow/BudgetCard.swift`
  - `/Users/staygreen/Documents/GitHub/Flamora/View/Cashflow/SavingsTargetCard.swift`
  - `/Users/staygreen/Documents/GitHub/Flamora/View/Cashflow/TransactionRow.swift`
- Existing Investment support components:
  - `/Users/staygreen/Documents/GitHub/Flamora/View/Investment/AccountsCard.swift`
  - `/Users/staygreen/Documents/GitHub/Flamora/View/Investment/AssetAllocationCard.swift`

This document intentionally describes only the current unconnected-state prototype. The connected-state experiment was removed and is out of scope for this spec.

## 1. Product Goal

This redesign is not a generic finance dashboard. The product framing is:
- Home is the narrative surface
- Cash Flow is the execution surface
- Investment is the asset-growth surface

The current prototype focuses on the unconnected state:
- Users have not fully connected their real accounts
- The app must still feel complete and intentional
- The UI must explain what each tab will unlock without relying on fake live data

Key design goals:
- Reduce “finance dashboard clutter”
- Make Home feel like a FIRE operating surface
- Make each tab visually distinct but still part of one system
- Preserve a premium iOS feel
- Keep glass use restrained

## 2. Scope

Included in this spec:
- One-file HTML prototype behavior and appearance
- Home unconnected state
- Home pull-down simulator interaction
- Cash Flow unconnected state
- Investment unconnected state
- Global shell, navigation, spacing, and motion rules

Not included:
- Connected-state production UI
- Backend integration
- Exact API implementation
- Final accessibility pass
- Android

### 2.1 Shell routing note (Journey vs MainTab)

The shipped app shell is **`MainTabView`**: global hero (`HomeHeroCardSurface` + `UnconnectedHeroContent` / `FIRECountdownCard`), draggable sheet, tab bar, and full-screen simulator overlay (`SimulatorView` + `BrandHeroBackground`). The Home tab’s sheet content is **`HomeRoadmapContent`**, not `JourneyContainerView`.

**`JourneyView` / `JourneyContainerView`** remain for shared logic (`JourneyViewModel`, `FIRECountdownCard`, sandbox wiring patterns) and future consolidation; they are **not** embedded in the current `MainTabView` tree. Do not assume `JourneyView` appears on device until explicitly wired.

## 3. Non-Negotiable Rules

These rules should be preserved during implementation:

1. Home, Cash Flow, and Investment remain inside the same main tab shell.
2. Home unconnected state is the default state.
3. Home simulator is drag-driven, not tap-driven.
4. Cash Flow and Investment are not fake live dashboards. They are preview surfaces.
5. Glassmorphism is allowed only as a restrained material treatment, not as full-page fog.
6. The bottom mini tab is floating and visually separate from page content.
7. Typography must stay close to current app conventions:
   - Main UI: SF Pro
   - No decorative font in main app screens

## 4. Visual System

### 4.1 Typography

Use SF Pro style throughout.

Reference typography from the prototype:
- Page title:
  - 30px
  - line-height ~0.98
  - letter-spacing ~-0.06em
  - weight 700
- Hero eyebrow/title:
  - 14px
  - uppercase
  - letter-spacing ~0.06em
  - weight 700
- Secondary helper copy:
  - 13px
  - weight 400 to 500
  - low contrast
- Large numeric headline:
  - Cash Flow: 38px
  - Investment: 40px
  - weight 700
  - tracking -0.05em to -0.07em
- Card labels:
  - 10px to 11px
  - uppercase when used as eyebrow/metric label

Typography principle:
- Numbers should feel strong, but not poster-sized
- Secondary copy should be quiet
- Labels should never compete with the main metric

### 4.2 Color Tokens

Core values currently used in the prototype:
- Ink: `#111827`
- Surface white: `#ffffff`
- FIRE gradient:
  - `#A78BFA`
  - `#FCA5A5`
  - `#FCD34D`

Home / Cash Flow / Investment dark gradient family:
- Uses a layered gradient structure
- Current background stack uses:
  - dark navy-violet top
  - purple/blue-violet middle
  - pale lavender fade lower down

Important product interpretation:
- These gradients are atmospheric
- Cards must remain visually dominant over the background

### 4.3 Radius

Current prototype radius system:
- Phone outer shell: 52px
- Phone inner screen: 38px
- Large sheet/card: 28px
- Secondary content panel: 24px
- Small metric blocks: 18px to 20px
- Pills/buttons: 999px

Implementation rule:
- Large primary cards: 28px
- Medium grouped sections: 24px
- Buttons and chips: full pill

### 4.4 Shadows and Glass

Use light, premium shadows:
- Large cards use soft vertical lift
- Avoid heavy black drop shadows
- Use subtle inner top highlight where needed

Glass use rules:
- Allowed on:
  - bottom mini tab
  - top icon chrome
  - light card surfaces where needed
- Not allowed:
  - full-page fog
  - low-contrast all-white haze that kills readability

## 5. Global Shell Spec

### 5.1 Device Frame

Prototype shell:
- Width: 430px
- Min height: 920px
- Screen height: 892px
- Status bar included at top

Implementation intent:
- The real app should preserve this large Pro-scale composition feel
- Vertical rhythm should feel generous

### 5.2 Top Chrome

Every top-level tab page has:
- Left: Flamora flame mark
- Right: settings icon
- Center area left intentionally open

Behavior:
- Chrome is part of page composition
- Chrome should not visually overpower the page title

### 5.3 Bottom Tab Bar

Structure:
- Floating glass pill bar
- Tabs:
  - Home
  - Cash
  - Invest

Material:
- Semi-translucent white
- Border and blur
- Strong active pill state

Behavior:
- Always visible in regular tab views
- Hidden during Home simulator expansion

Implementation target:
- `/Users/staygreen/Documents/GitHub/Flamora/View/MainTabView.swift`
- Existing tab bar concept already exists via `GlassmorphicTabBar`

## 6. Home Unconnected State

### 6.1 Home Intent

Home in unconnected state must do two jobs:
- Show a light teaser of the FIRE journey
- Show the next setup actions

It must not pretend real account data exists.

### 6.2 Home Layout

Home consists of two layers:

1. Top dark gradient hero layer
2. Bottom white sheet that overlaps upward

The white sheet is the primary interaction surface.

### 6.3 Hero Layer — must match `home-rebuild-glass-prototype.html`

The **top background** (hero layer fill) is not a generic “dark gradient.” It must reproduce the prototype’s **`--brand-purple-surface` / `--hero-fade`** stack:

- Layered **radial** highlights (soft purple / pink washes at fixed anchor positions).
- **Linear** vertical blend: deep navy-violet top (`#15162a` region) through mid blues (`#242b63`, `#5a6fe0`) to pale lavender / off-white bottom (`#d8dbff` → `#f7f3ff`).
- Same **corner treatment** as `.hero-layer` in the HTML (bottom corners when not in simulator mode).

Implementation must **open the prototype in a browser and match by eye**; do not substitute a flat two-stop gradient.

Current Home unconnected hero content:
- Title: `Your FIRE Journey`
- Subtitle: `Finish the set up to track your progress.`
- Ghost progress rail
- Small right-aligned `Freedom date` label

Visual rules:
- Hero is not a boxed card
- Hero is printed directly into the background surface
- The content should feel calm, not busy

Do not add:
- Fake percentage
- Fake FIRE date
- Large explanatory paragraphs

### 6.4 White Sheet

White sheet rules:
- Slight upward overlap into hero
- Rounded top corners
- Bright, clean, and clearly separated from the background
- Draggable

Current content inside sheet:
- Handle
- `What happens next`
- Three-step roadmap

Steps:
1. Set your FIRE goal
2. Connect your accounts
3. Choose your path

Each step includes:
- Number bubble
- Title
- One-line explanation
- Right arrow action

### 6.5 Home Simulator Interaction

This is the most important interaction in the prototype.

User behavior:
- User presses and drags the white sheet downward
- The dark hero background expands with the drag
- Simulator content fades in progressively

Do not implement as:
- Tap to open modal
- Simple full-screen cover
- One-shot spring with no finger tracking

Required behavior:
- The sheet must track the pointer/finger continuously
- Expansion is proportional to drag distance
- Releasing snaps either back to Home or down into Simulator

Current prototype implementation characteristics:
- Drag-based
- Threshold-based snap
- Tab bar fades out during expansion
- White return label appears when sufficiently expanded

### 6.6 Simulator Layout

Current simulator structure:
- Sandbox tag
- Headline: `You will be financial free by age 30.`
- Embedded bar chart (see **6.6.1 Embedded graph**)
- Retirement Detail panel
- Advanced Details expandable section

#### 6.6.1 Embedded graph (trend bars — “Figure 2” / prototype `.sim-graph`)

This block is the **same visual language as the standalone reference** (semi-transparent white bars on the blue gradient “wall”). Rules:

1. **Background wall:** Bars sit **on the hero gradient plane**, not inside a separate white card. The chart area uses the **same** `--hero-fade` background as the rest of the hero (no extra boxed chart container with a different fill).
2. **Monochrome only:** Bars use **white at varying opacity** (prototype: `.bar` vs `.bar.soft` — stronger vs softer white gradients). **No** category colors, **no** multi-hue fills, **no** green/red semantics on bars.
3. **Bar shape:** Rounded **top** caps (prototype: `border-radius` tall pill on top, slight radius at bottom). Bars grow left → right along an exponential-style curve (many short bars early, tallest at the end).
4. **Baseline & axis:** A single faint **horizontal baseline** (`rgba(255,255,255,~0.14)`). **Sparse** year labels under the grid only (e.g. `2026` / `2029` / `2032`), low-contrast white. No Y-axis grid lines, no tick spam.
5. **Labels — leading point only:** Only the **leading point** (the **terminal / FIRE target bar**, rightmost peak in the series) carries the **money + age** label in UI. Format matches prototype callout: e.g. `$128,000 by age 30`. **No** per-bar value labels on other columns. (Optional: tap-to-inspect detail can still update a detail panel; the **floating glass pill** stays single-target unless product explicitly adds more.)
6. **Callout chrome:** One **glass pill** (`backdrop-filter` blur, semi-white fill, thin light border) positioned near the leading bar, same as `.bar-callout` in the HTML.

Chart rules (summary):
- Chart is part of the **background plane**
- **Monochrome** white bars on the gradient field
- **One** money+age callout on the **leading (target) bar** only

Variables shown:
- Current Age
- Monthly Contribution
- Current Investment
- Retire Monthly Expense
- Expected Return
- Inflation
- Withdrawal Rate

Behavior:
- Variable rows are tap-to-edit
- Advanced details collapsible
- Chart bars may be tappable for **detail/inspector** updates (optional; matches prototype JS). **Do not** add extra floating money/age pills per bar; **one** glass callout for the target bar only (**D9**).

Implementation target:
- `/Users/staygreen/Documents/GitHub/Flamora/View/Journey/SimulatorView.swift`

Recommended translation:
- Keep `JourneyView` as Act 1
- Move this drag-linked expansion into the transition into `SimulatorView`, or build a dedicated drag-linked preview shell above the existing simulator

## 7. Cash Flow Unconnected State

### 7.1 Intent

Cash Flow in unconnected state should preview what the tab will unlock.
It is not a blank state and not a real data screen.

### 7.2 Layout

Structure:
- Dark gradient page background
- Top title: `Cash Flow`
- One central stage
- One full card visible at a time
- Bottom CTA: `Connect accounts`
- Bottom floating tab bar

### 7.3 Card System

Cards rotate automatically:
- Card 1: Spending overview
- Card 2: Saving overview

Only one full card should be visible at once.
The hidden card must not visibly overlap underneath.

### 7.4 Spending Card

Current content:
- Eyebrow: `Spending overview`
- Main amount: `$3,420`
- Supporting line: `Monthly spending split into needs and wants.`
- Right chip: `Spending`
- Two internal blocks:
  - Needs
  - Wants

Needs block:
- `$2,120`
- Progress line
- Rows:
  - Rent `$1,480`
  - Groceries `$410`
  - Utilities `$230`

Wants block:
- `$1,300`
- Progress line
- Rows:
  - Dining `$420`
  - Shopping `$515`
  - Travel `$365`

### 7.5 Saving Card

Current content:
- Eyebrow: `Saving overview`
- Main amount: `$20,200`
- Supporting line: `Total saved this year from consistent monthly habits.`
- Right chip: `Saving`
- Bar chart by month
- Stats row:
  - Target rate `20%`
  - Target saving `$2,000`

### 7.6 Cash Flow Motion

Card behavior:
- Autoplay loop
- One card visible at a time
- Smooth fade/translate swap

CTA behavior:
- Static
- Does not overlap card
- Black button with white text

Implementation targets:
- `/Users/staygreen/Documents/GitHub/Flamora/View/Cashflow/CashflowView.swift`
- Existing implementation pieces that may be reused:
  - `IncomeCard.swift`
  - `BudgetCard.swift`
  - `SavingsTargetCard.swift`
  - `TransactionRow.swift`

Implementation note:
- The production app already has real connected data cards
- For the unconnected redesign, create a dedicated preview shell at the top-level tab state instead of trying to force the existing data cards to behave like teaser cards

## 8. Investment Unconnected State

### 8.1 Intent

Investment in unconnected state should preview the future portfolio surface.
It should feel premium, restrained, and closer to the onboarding `WelcomeNetWorthCard` than a real portfolio dashboard.

### 8.2 Layout

Structure:
- Dark gradient background
- Top title: `Investment`
- One central glass-light card
- Bottom CTA: `Connect accounts`
- Bottom tab bar

### 8.3 Card Content

Current card content:
- Eyebrow: `Total Net Worth`
- Main amount: animated from `$0` to `$210,150`
- Change: `+13.8%`
- Single line chart
- End dot with halo
- Time range pills:
  - `1W`
  - `1M` active
  - `3M`
  - `YTD`
  - `All`
- Footer copy:
  - `Track all your investment in one place`

### 8.4 Motion

Current motion sequence:
1. Number counts up
2. Line draws left to right
3. End dot and halo appear

Animation guidance:
- Should feel slower and more premium
- Avoid overly fast reveal

### 8.5 Visual Rules

Important:
- Card should not be too white and dead-flat
- Card can have light glass material
- Background should remain visible behind it
- Readability must stay high

Implementation targets:
- `/Users/staygreen/Documents/GitHub/Flamora/View/Investment/InvestmentView.swift`
- Existing card inspiration:
  - `/Users/staygreen/Documents/GitHub/Flamora/View/Journey/PortfolioCard.swift`
  - `/Users/staygreen/Documents/GitHub/Flamora/View/Onboarding/Views/OB_WelcomeView.swift`

Implementation note:
- The onboarding net worth card is the closest reference for hierarchy and motion
- The actual Investment tab should not inherit the onboarding background, only the card language

## 9. Exact Interaction Rules

### 9.1 Home Sheet Drag

Required:
- Pointer down on white sheet starts drag
- White sheet follows finger
- Dark hero expands in sync
- Simulator pieces appear progressively

Current prototype tuning:
- Drag is intentionally damped
- Release threshold is conservative to avoid accidental snap-open
- During drag, transitions on hero/sheet/simulator layers are disabled to preserve finger-tracking feel

### 9.2 Home Step Cards

Each roadmap row:
- Entire row tappable
- Arrow tappable
- Tapping row updates note state in prototype

Production expectation:
- Row should route into the relevant setup flow

### 9.3 Simulator Variable Editing

Each detail row:
- Tap row to edit
- Replace value with input field
- Commit on blur or Enter
- Escape cancels

### 9.4 Cash Flow Card Rotation

Autoplay only.

Rules:
- First card visible on tab entry
- Rotate on timer
- Switching away from the tab should stop autoplay
- Returning to tab may restart autoplay

### 9.5 Investment Card Animation

Rules:
- Animation starts when entering Investment tab
- Number counts up
- Line reveal restarts
- End halo appears last

## 10. Spacing Spec

Use these as baseline translation values:

Global shell:
- Page side padding inside phone: 24px
- Large module gap: 18px to 22px

Home:
- Hero top padding: 18px
- Hero bottom padding: 100px before white sheet overlap
- White sheet top overlap: about -76px
- White sheet internal padding: 16px top, 18px sides, 116px bottom

Cash Flow:
- Stage top offset: about 176px
- Card padding: 20px
- CTA bottom offset: about 52px

Investment:
- Stage top offset: about 174px
- Card padding: 22px top, 20px horizontal, 18px bottom

## 11. Data Contract for Unconnected Prototype

These are mock-only display values in the current prototype.

### Home simulator mock data
- Age target headline: `30`
- Bar series years: `2026`, `2029`, `2032`
- Variable defaults:
  - Current Age: `24`
  - Monthly Contribution: `$1,800`
  - Current Investment: `$42,000`
  - Retire Monthly Expense: `$3,600`
  - Expected Return: `7%`
  - Inflation: `2.5%`
  - Withdrawal Rate: `4%`

### Cash Flow mock data
- Spending total: `$3,420`
- Needs: `$2,120`
- Wants: `$1,300`
- Savings overview: `$20,200`
- Target rate: `20%`
- Target saving: `$2,000`

### Investment mock data
- Net worth total: `$210,150`
- Change: `+13.8%`
- Footer copy:
  - `Track all your investment in one place`

## 12. Implementation Mapping by Project File

### Main tab structure

File:
- `/Users/staygreen/Documents/GitHub/Flamora/View/MainTabView.swift`

Responsibilities:
- Keep Home / Cash Flow / Investment in one shell
- Preserve bottom tab bar
- Maintain settings access
- Control simulator presentation strategy

### Home

Primary file:
- `/Users/staygreen/Documents/GitHub/Flamora/View/Journey/JourneyView.swift`

Likely responsibilities:
- Act 1 top hero
- Guided setup card / roadmap
- Entry into sandbox

Potential supporting refactors:
- `/Users/staygreen/Documents/GitHub/Flamora/View/Journey/FIRECountdownCard.swift`
- `/Users/staygreen/Documents/GitHub/Flamora/View/Journey/ProgressBar.swift`
- `/Users/staygreen/Documents/GitHub/Flamora/View/Journey/JourneyContainerView.swift`

Recommendation:
- Use `JourneyView` as the structural container
- Replace current hero/guided shell hierarchy with the new one
- Do not implement the HTML literally; translate the structure into native SwiftUI sections

### Simulator

Primary file:
- `/Users/staygreen/Documents/GitHub/Flamora/View/Journey/SimulatorView.swift`

Recommendation:
- Separate content structure from transition mechanics
- Keep the simulator data inputs and graph in SimulatorView
- Put drag-linked transition behavior either in JourneyContainerView or a dedicated home shell wrapper

### Cash Flow

Primary file:
- `/Users/staygreen/Documents/GitHub/Flamora/View/Cashflow/CashflowView.swift`

Recommendation:
- The existing connected experience already exists
- Add a dedicated unconnected preview state at the top-level, rather than trying to mutate the live connected cards
- Existing connected cards remain useful for later connected-state implementation

### Investment

Primary file:
- `/Users/staygreen/Documents/GitHub/Flamora/View/Investment/InvestmentView.swift`

Recommendation:
- Preserve connected production logic separately
- Add a dedicated unconnected preview card when no bank is linked
- Reuse `PortfolioCard` concepts where helpful, but follow the prototype’s simpler hierarchy

## 13. Build Order

Recommended implementation order:

1. Global shell and top chrome
2. Home hero background and white sheet
3. Home roadmap card
4. Drag-linked Home simulator transition
5. Simulator detail panel
6. Cash Flow unconnected stage
7. Cash Flow spending and saving cards
8. Investment unconnected card
9. Animation polish
10. Tab bar and final spacing polish

## 14. Acceptance Checklist

The implementation is considered aligned only if all of the following are true:

### Home
- Home hero is printed into the gradient background, not boxed
- Hero gradient matches `design-reference/home-rebuild-glass-prototype.html` (`--brand-purple-surface` / `--hero-fade`)
- White sheet overlaps upward
- Roadmap has three clear setup steps
- Drag interaction is finger-tracked, not modal-like
- Simulator expansion feels continuous

### Home simulator (embedded graph)
- Bar chart sits on the hero gradient plane (wall), not inside a separate filled chart card
- Bars are monochrome white opacity variants only (no per-bar colors)
- Exactly one glass callout with money + age on the **leading / target** bar; sparse year labels on the baseline row only

### Cash Flow
- Background is dark gradient
- Only one card is visible at a time
- Cards autoplay
- CTA is black with white text
- Card remains fully visible and not blocked by CTA

### Investment
- Single portfolio preview card
- Number + line + dot animation present
- Time pills included
- Footer copy present
- CTA is black with white text

### Global
- Bottom tab bar floats
- SF Pro feel preserved
- Glass is light and intentional
- Gradients do not overpower cards
- Readability stays high

## 15. Explicit Do-Not-Do List

Do not:
- Add extra explanatory copy to hero surfaces
- Use heavy full-page glass blur
- Hide interactions behind unclear gestures
- Fake connected-state data in the unconnected spec
- Replace the bottom tab with a standard flat tab bar
- Introduce unrelated redesigns in Settings or onboarding

## 16. Design Review Decisions (plan-design-review 2026-04-08, updated same day)

The following design decisions were resolved during the `/plan-design-review` pass.
They are binding and must be implemented as specified.

**Supplement (embedded graph + hero parity):** D8–D9 lock the Home hero gradient and simulator bar graph to `design-reference/home-rebuild-glass-prototype.html` and the “Figure 2” monochrome wall-integrated treatment.

### D1 — Home Hero Layout: ZStack (Pass 1, Issue 1)
- **Decision:** Use `ZStack` for the Home Hero section.
- **Topbar** (`Flamora logo + settings button`) is absolutely pinned to the top of the hero using `.frame(maxHeight: .infinity, alignment: .top)`.
- **Hero content** (`Your FIRE Journey` title, subtitle, progress bar) is positioned below the topbar.
- **On drag:** only the hero content fades out via `.opacity(1 - dragProgress)`. The topbar remains fully visible at all times.
- **Why:** The prototype's core interaction requires the Flamora brand mark to remain visible throughout the drag gesture. A `VStack` would cause the topbar to animate away with the content.

### D2 — Hero Entry Animation (Pass 3, Issue 3A)
- **Decision:** Sequential entry animation on first load.
- **Step 1:** Hero fades in — `withAnimation(.easeOut(duration: 0.2)) { heroOpacity = 1 }`
- **Step 2:** After 120ms delay — Sheet slides up from bottom + fades in: `withAnimation(.easeOut(duration: 0.32)) { sheetOffset = 0; sheetOpacity = 1 }`
- **Why:** Sequential reveal builds spatial hierarchy — user sees the background context first, then the action layer.

### D3 — Tab Switch Animation (Pass 3, Issue 3B)
- **Decision:** Cross-fade on tab switch.
- **Implementation:** Apply `.animation(.easeInOut(duration: 0.2), value: selectedTab)` on the tab content container in `MainTabView`.
- **Why:** Default SwiftUI tab switching is a hard cut. Cross-fade aligns with the glass material aesthetic.

### D4 — Tab Bar Drag Animation (Pass 7)
- **Extracted from prototype JS:** `tabbar.style.opacity = 1 - progress; tabbar.style.transform = translateY(16 * progress)`
- **SwiftUI implementation:** `.opacity(1.0 - dragProgress).offset(y: 16 * dragProgress)`
- **Pointer disable threshold:** When `dragProgress > 0.7`, tab bar becomes non-interactive (`.allowsHitTesting(dragProgress <= 0.7)`)

### D5 — Sheet Peek Label (Pass 7)
- **Text:** "Back to Home"
- **Appearance:** Fades in when `dragProgress > 0.72`
- **Opacity formula:** `clamp((dragProgress - 0.72) / 0.28, 0, 1)`

### D6 — Missing Color Tokens (Pass 5)
The following tokens must be added to `Style/Colors.swift` before implementation:
```swift
// Investment Hero (distinct from Home heroGradient)
static let investHeroGradient: [Color] = [
    Color(hex: "#13152a"),
    Color(hex: "#20275f"),
    Color(hex: "#556add"),
    Color(hex: "#d9dcff"),
    Color(hex: "#f8f4ff"),
]

// Tab Bar glass surface
static let tabBarFill   = Color.white.opacity(0.68)
static let tabBarBorder = Color.white.opacity(0.82)
static let tabBarShadow = Color(hex: "#111827").opacity(0.16)

// Simulator details panel (dark glass)
static let simDetailsBg1 = Color(hex: "#21254E").opacity(0.94)
static let simDetailsBg2 = Color(hex: "#191C3D").opacity(0.96)
```

### D7 — Glass Card Shadow Encapsulation (Pass 5)
- **Decision:** Create `Style/Shadows.swift` with a `.glassCardShadow()` ViewModifier.
- **Shadow spec (two layers):**
  - Layer 1: `color: Color(hex: "#473765").opacity(0.12), radius: 40, x: 0, y: 18`
  - Layer 2: `color: Color(hex: "#473765").opacity(0.05), radius: 8, x: 0, y: 2`
- **Usage:** `.glassCardShadow()` replaces all inline shadow calls on glass cards.

### D8 — Home hero background = `home-rebuild-glass-prototype.html` (plan-design-review 2026-04-08)
- **Decision:** The Home **hero-layer** fill must match the prototype’s **`--brand-purple-surface`** stack: radials + `linear-gradient(180deg, #15162a 0%, #242b63 18%, #5a6fe0 42%, #d8dbff 68%, #f7f3ff 100%)` (see `design-reference/home-rebuild-glass-prototype.html` `:root` and `.hero-layer`).
- **Verification:** Side-by-side with Safari/WebKit rendering of the HTML file on the same viewport width class.
- **Why:** User-facing spec: “顶部背景和 prototype 一致（图一玻璃 + 渐变氛围）.”

### D9 — Simulator embedded graph: wall-integrated, monochrome, single money+age pill (plan-design-review 2026-04-08)
- **Decision:** The simulator **trend** is the **embedded bar graph** from the prototype (`.sim-graph` / `.graph-box`), not a multi-color chart.
- **Integration:** Bars are drawn **on the hero gradient** (background wall). No chart-in-white-card treatment for this graph.
- **Palette:** **Only** white at varying opacity (`.bar` / `.bar.soft` semantics). **禁止**柱间彩色编码或语义色。
- **Labels:** **Only** the **leading (terminal / FIRE target) bar** shows the floating **glass pill** with **currency + age** (e.g. `$128,000 by age 30`). Other bars: **no** inline amount/age labels.
- **Geometry:** Rounded-top bars, faint horizontal **floor** line, sparse **year** labels on the axis row only.
- **Why:** Matches reference “图二 Embedded Graph” and the in-file note: “The bar chart is part of the background wall. Only the leading point needs the money and age label.”

---

## 17. Handoff Note for Teammates

If another engineer implements this spec:
- Use the HTML prototype as visual reference
- Use this markdown as the implementation contract
- Do not improvise hierarchy changes without checking against the prototype
- Small visual adjustments are okay
- Structural changes are not okay unless explicitly approved

The correct interpretation is:
- reproduce the hierarchy
- preserve the motion language
- preserve the material balance
- translate it natively into SwiftUI

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 1 | CLEAR | Previous session |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | — | — |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAR (PLAN) | 11 issues, 0 critical gaps |
| Design Review | `/plan-design-review` | UI/UX gaps | 2 | CLEAR (FULL) | score: 4/10 → 8/10; +D8/D9 hero + embedded graph parity |

**UNRESOLVED:** 0 design decisions deferred
**VERDICT:** ENG + DESIGN CLEARED — ready to implement (hero + simulator graph per D8/D9)
