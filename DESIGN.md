# Design System — Flamora

## Product Context
- **What this is:** FIRE (Financial Independence, Retire Early) tracker — users track progress toward their financial independence number
- **Who it's for:** People pursuing FIRE who want a daily dashboard, not a spreadsheet
- **Space:** Personal finance / goal tracking
- **Project type:** iOS SwiftUI app, dark theme, native components only

---

## Aesthetic Direction

- **Direction:** Dark Minimal + Warm Flame
- **Decoration level:** Intentional — the fire gradient is the only decorative move; everything else is surface-level neutrals and structured type
- **Mood:** Serious and focused, with a single warm signal that progress is being made. The FIRE number and countdown are heroes. Nothing competes with them.
- **Core rule:** The gradient is used sparingly and only where it carries meaning — progress bars, border accents, hero text. Never as wallpaper.

---

## Color

### Brand Gradient
```
gradientFire    linear: #A78BFA → #FCA5A5 → #FCD34D   (violet → rose → amber)
gradientStart   #A78BFA   violet
gradientMiddle  #FCA5A5   rose
gradientEnd     #FCD34D   amber
```

### Background
```
backgroundPrimary     #000000   page-level background
backgroundSecondary   #0F1419   alternate page background
backgroundInput       #1E2530   input fields
```

### Surface (card-level)
```
surface              #121212   main card background
surfaceElevated      #1A1A1A   icon backgrounds, nested elements
surfaceBorder        #222222   1pt card borders
surfaceHighlight     #1E1E1E   pressed / hover state
surfaceInput         #2C2C2E   progress tracks, input fills
```

### Text
```
textPrimary      #FFFFFF   primary labels, numbers
textSecondary    #9CA3AF   sublabels, row titles, supporting text
textTertiary     #6B7280   muted labels, footnotes
textMuted        #4B5563   ghost text, captions
textInverse      #000000   text on white buttons
```

### Semantic
```
success   #10B981   positive values, connected state
warning   #F59E0B   attention (notification off, budget at limit)
error     #EF4444   negative values, failed state
info      #3B82F6   neutral informational
```

### Accent
```
accentPurple        #A78BFA   primary accent, matches gradientStart
accentBlue          #93C5FD
accentPink          #F9A8D4
accentAmber         #FCD34D   matches gradientEnd
accentGreen         #34D399
accentGreenDeep     #059669
accentRed           #EF4444   (= error)
```

### Overlay White System
Used for glass surfaces, progress tracks, dividers. Named by opacity:
```
overlayWhiteWash              0.04   barely-there fills, tracks
overlayWhiteStroke            0.08   progress bar tracks, subtle dividers
overlayWhiteMid               0.12   glass pill backgrounds
overlayWhiteHigh              0.18   glass card sheen
overlayWhiteForegroundSoft    0.30   inactive dots, muted foreground
overlayWhiteForegroundMuted   0.45   muted labels on glass
overlayWhiteOnGlass           0.75   high-contrast text on glass
```

Exception allowed: `Color.black.opacity(0)` / `Color.clear` as gradient transparent stops — SwiftUI rendering requirement.

---

## Typography

Single entry point: `appFont()` in `Style/Typography.swift`. Change the entire app's typeface by editing one function.

**Current typeface:** SF Pro (system default)
**Onboarding exception:** `.obQuestion` uses Playfair Display (serif, 24pt semibold) for onboarding question headings only.

### Size Scale (`AppTypography`)
```
display             40pt
h1                  32pt
h2                  24pt
h3                  20pt
h4                  18pt
body                16pt
bodySmall           14pt
cardFigureSecondary 15pt
caption             12pt
label               10pt
```

### Token Reference

| Token | Size | Weight | Use |
|-------|------|--------|-----|
| `.display` | 40 | bold | Large hero titles |
| `.h1` | 32 | bold | Page main title |
| `.h2` | 24 | bold | Section header |
| `.h3` | 20 | semibold | Subheading, quote body |
| `.h4` | 18 | semibold | Subsection label |
| `.detailSheetTitle` | 32 | bold | Sheet large header (= h1) |
| `.detailTitle` | 22 | bold | Sheet sub-header |
| `.currencyHero` | 48 | bold | Large currency display |
| `.cardFigurePrimary` | 28 | bold | Card hero number |
| `.portfolioHero` | 34 | semibold | Portfolio balance |
| `.statRowSemibold` | 17 | semibold | Stats row emphasis |
| `.fieldBodyMedium` | 17 | medium | Input field text |
| `.bodyRegular` | 16 | regular | Body text |
| `.bodySemibold` | 16 | semibold | Emphasized body |
| `.supportingText` | 15 | regular | CTA supporting copy |
| `.figureSecondarySemibold` | 15 | semibold | Row summary label |
| `.cardFigureSecondary` | 15 | bold | Card secondary number |
| `.inlineLabel` | 14 | medium | Row labels, sublabels |
| `.inlineFigureBold` | 14 | bold | Inline number emphasis |
| `.bodySmall` | 14 | regular | Small body |
| `.bodySmallSemibold` | 14 | semibold | Small body emphasis |
| `.footnoteRegular` | 13 | regular | Footnotes, timestamps |
| `.footnoteSemibold` | 13 | semibold | Emphasized footnote |
| `.footnoteBold` | 13 | bold | Card compact chrome |
| `.smallLabel` | 12 | semibold | Compact labels |
| `.caption` | 12 | regular | Captions |
| `.cardHeader` | 11 | bold | Uppercase card titles (tracking 0.8) |
| `.cardRowMeta` | 11 | medium | Row metadata |
| `.label` | 10 | semibold | Tiny labels |
| `.miniLabel` | 9 | semibold | Badges, pills |
| `.sheetPrimaryButton` | 18 | bold | Sheet primary CTA |
| `.sheetCloseGlyph` | 28 | regular | Dismiss × button |
| `.chromeIconMedium` | 18 | medium | Tab bar icons |
| `.navChevron` | 26 | semibold | Full-screen back button |
| `.categoryRowIcon` | 21 | semibold | List leading icons |
| `.quoteBody` | 20 | bold | Quote card body |
| `.obQuestion` | 24 | semibold | Onboarding questions (Playfair Display) |

### Tracking
```
cardHeader      0.8pt   all uppercase card headers
miniUppercase   0.5pt   compact uppercase micro-labels
```

---

## Spacing

Base unit: **8pt**

```swift
AppSpacing.xs            4pt
AppSpacing.sm            8pt
AppSpacing.md           16pt
AppSpacing.lg           24pt
AppSpacing.xl           32pt
AppSpacing.xxl          48pt

AppSpacing.cardPadding  20pt   inside card VStack
AppSpacing.cardGap      16pt   between cards in a scroll stack
AppSpacing.screenPadding 16pt  horizontal scroll content margins
AppSpacing.sectionGap   24pt   between settings sections
AppSpacing.rowItem      14pt   horizontal item spacing in rows
AppSpacing.sectionLabelGap 10pt  gap between section label and content
AppSpacing.tabBarReserve  70pt  bottom padding for tab bar clearance
```

---

## Border Radius

```swift
AppRadius.sm      8pt    small elements (icon bg, small pill)
AppRadius.md      12pt   medium containers
AppRadius.card    16pt   cards, sheets, modals
AppRadius.lg      20pt   large sheets
AppRadius.xl      24pt   extra large containers
AppRadius.button  28pt   primary CTAs (56pt height / 2 = 28pt = pill)
AppRadius.full    9999pt true pill / circle
```

---

## Button Style (Primary CTA)

White background, black text, 56pt height, `AppRadius.button` corners.

```swift
// Standard primary button
Text("Connect Accounts")
    .font(.sheetPrimaryButton)   // 18pt bold
    .foregroundStyle(AppColors.textInverse)
    .frame(maxWidth: .infinity)
    .frame(height: 56)
    .background(AppColors.textPrimary)
    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
```

---

## Motion

- **Approach:** Minimal-functional
- **Pattern:** `@State var appear = false`, fade + vertical offset, staggered delays
- **Enter:** ease-out, 0.4–0.6s
- **Exit:** ease-in, 0.2–0.3s
- **Stagger:** 0.05–0.08s between sibling elements

---

## Card Patterns

### Standard card
```swift
VStack { ... }
    .padding(AppSpacing.cardPadding)
    .background(AppColors.surface)
    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
    // or with explicit border:
    .overlay(RoundedRectangle(cornerRadius: AppRadius.card)
        .stroke(AppColors.surfaceBorder, lineWidth: 1))
    .padding(.horizontal, AppSpacing.screenPadding)
```

### Fire gradient border (hero card only)
```swift
ZStack {
    RoundedRectangle(cornerRadius: AppRadius.card)
        .fill(AppColors.surface)
    RoundedRectangle(cornerRadius: AppRadius.card)
        .strokeBorder(
            LinearGradient(colors: AppColors.gradientFire,
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            lineWidth: 1
        )
    // content
}
.padding(.horizontal, AppSpacing.screenPadding)
```

Use only for `FIRECountdownCard`. All other cards use `surfaceBorder`.

### Card header (all caps)
```swift
Text("YOUR FIRE JOURNEY")
    .font(.cardHeader)
    .foregroundStyle(AppColors.textSecondary)
    .tracking(AppTypography.Tracking.cardHeader)
```

---

## Component Specs

### FIRECountdownCard

Timeline layout: progress bar acts as the journey from start to estimated FIRE date.

```
YOUR FIRE JOURNEY

28%  of the way there

▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░

Apr 6, 2026              Apr 6, 2040
Started                  $2.4M target
```

- Progress bar track: `AppColors.overlayWhiteStroke` (0.08 opacity)
- Progress fill: fire gradient left→right
- Left anchor: `goal.createdAt` formatted `MMM d, yyyy`
- Right anchor: `Date() + yearsRemaining years` formatted `MMM d, yyyy`
- States: loaded / loading (skeleton) / empty (no bank connected)

> **TODO (backend):** `yearsRemaining: Int` is imprecise (whole years only). Edge Function should return `estimated_fire_date` as ISO 8601, or `months_remaining: Int`, so the arrival date is accurate to the month. See `project_fire_date_backend.md`.

### Report Screens — Story Format (v2)

**Applies to:** `MonthlyReportView`, `IssueZeroView`, `AnnualReportView`

**Design direction:** Instagram Stories / Spotify Wrapped. One metric per full-screen slide. Swipe left/right to advance. No scrolling within a story.

**Approved:** 2026-04-06.

---

#### Story Anatomy (shared across all three views)

```
┌─────────────────────────────────┐
│  ███░░░░  progress segments     │  2pt height, overlayWhiteStroke track, white fill
│                                 │
│  SECTION LABEL                  │  cardHeader (11pt bold, tracking 0.8, textSecondary)
│                                 │
│                                 │
│         [hero number]           │  64pt bold, −2pt letter-spacing
│         [supporting line]       │  bodyRegular, textSecondary
│                                 │
│         [context rows]          │  inlineLabel / footnoteSemibold
│                                 │
│  ← tap zone     tap zone →      │  left 30% / right 70% invisible tap areas
│                                 │
│         ● ○ ○ ○ ○               │  dot indicators: 18×6pt active, 6×6pt inactive
└─────────────────────────────────┘
```

**Progress bar:** One segment per story. Active segment fills white; inactive = `overlayWhiteStroke`. 4pt gap between segments. 2pt height, full width with `AppSpacing.md` horizontal padding.

**Hero number:** 64pt bold, −2pt letter-spacing. Gradient text (`gradientFire`) for directional metrics (FIRE date delta). White (`textPrimary`) for neutral values. Green (`success`) for positive rates. Red (`error`) for negative.

**Background:** Radial gradient from a dim accent color outward to `backgroundPrimary` (#000000). Each story type has a distinct accent tone (see per-screen specs below).

**Dot indicators:** Bottom-center. Active dot: 18×6pt rounded pill. Inactive dot: 6×6pt circle. Color: `overlayWhiteForegroundSoft` (inactive), `textPrimary` (active). 4pt gap between dots.

**Tap zones:** Two invisible full-height tap areas. Left 30% → previous story. Right 70% → next story. When on first story, left tap dismisses. When on last story, right tap dismisses.

**Navigation:** `TabView` with `.tabViewStyle(.page(indexDisplayMode: .never))`. Custom dot indicators drawn separately (SwiftUI PageTabViewStyle dots don't match design).

---

#### MonthlyReportView — 5 Stories

Trigger: User taps notification "Your April report is ready" or opens from home card.

| # | Story | Background accent | Hero | Supporting |
|---|-------|-------------------|------|------------|
| 1 | **FIRE DATE** | purple (#A78BFA, dim) | Delta in months (grad-text) | "vs last month" sublabel |
| 2 | **SAVINGS RATE** | green (#10B981, dim) | Rate % (green if ≥ target, red if below) | "$X saved this month" |
| 3 | **SPENDING** | amber (#FCD34D, dim) | Top 3 categories as rows | Outlier category highlighted in amber |
| 4 | **INCOME** | blue (#93C5FD, dim) | Total income (white) | Extra income callout if present |
| 5 | **AI INSIGHT** | surface (#111111) | 2-sentence AI summary (bodyRegular, textPrimary) | Groq/Llama-generated, no hero number |

Story 5 (AI Insight) omits the large hero number. Uses full-width text block centered vertically with a subtle left accent bar (4pt, gradient).

---

#### IssueZeroView — 4 Stories

Trigger: User connects first bank account. Shown immediately after connection success.

| # | Story | Background accent | Hero | Supporting |
|---|-------|-------------------|------|------------|
| 1 | **WELCOME** | purple (#A78BFA, dim) | "Here's what\nwe found." (h1, textPrimary) | Month range of data analyzed |
| 2 | **SAVINGS RATE** | green (#10B981, dim) | Avg savings rate % | "across X months of data" |
| 3 | **TOP CATEGORY** | amber (#FCD34D, dim) | Top spend category + amount | "$X/mo on [Category]" |
| 4 | **TEASER** | surface (#111111) | "Starting next month" headline (h2) | Bullet list: Monthly reports, Annual summary. Primary CTA button at bottom. |

Story 4 (Teaser) includes the primary CTA button ("Got it") using standard white-bg button style. This is the only story with a tappable button element.

---

#### AnnualReportView — 4 Stories

Trigger: January 1st push notification, or user opens from home card.

| # | Story | Background accent | Hero | Supporting |
|---|-------|-------------------|------|------------|
| 1 | **FIRE DATE** | purple (#A78BFA, dim) | Delta in months over the year (grad-text) | "Your FIRE date moved X months [closer/further]" |
| 2 | **YEAR IN NUMBERS** | surface (#111111) | 2×2 stat grid | Savings rate / Total saved / Best month / Investment return |
| 3 | **BIGGEST OUTLIER** | amber (#FCD34D, dim) | Top spend category total for year | Comparison to prior year if available |
| 4 | **AI INSIGHT** | surface (#111111) | Year-in-review AI summary | Same layout as MonthlyReportView story 5 |

Story 2 (Year in Numbers) uses a 2×2 grid instead of a single hero number. Each cell: `footnoteSemibold` label (textSecondary) + `cardFigurePrimary` value (textPrimary). Grid has `AppSpacing.md` gap.

---

#### SwiftUI Implementation Notes

```swift
// Story container — use TabView with page style
TabView(selection: $currentStory) {
    ForEach(stories.indices, id: \.self) { index in
        StorySlideView(story: stories[index])
            .tag(index)
    }
}
.tabViewStyle(.page(indexDisplayMode: .never))
.ignoresSafeArea()

// Progress bar segment
RoundedRectangle(cornerRadius: 1)
    .fill(index <= currentStory
        ? AppColors.textPrimary
        : Color.white.opacity(AppColors.Opacity.overlayWhiteStroke))
    .frame(height: 2)

// Hero number with gradient text
Text(deltaLabel)
    .font(.system(size: 64, weight: .bold))   // NOTE: new token needed — see below
    .kerning(-2)
    .foregroundStyle(
        LinearGradient(colors: AppColors.gradientFire,
                       startPoint: .leading, endPoint: .trailing)
    )
```

**New typography token needed:** `.storyHero` — 64pt bold, −2pt kerning. Add to `Style/Typography.swift` before implementing these views.

```swift
// In AppTypography
static let storyHero: CGFloat = 64

// In Font extension
static var storyHero: Font { appFont(AppTypography.storyHero, .bold) }
```

---

### Settings Notification Entry (v2)

Shown only when `UNAuthorizationStatus == .denied`. Opens iOS Settings.

```
NOTIFICATIONS

[ bell icon ]  Notifications
               Off — tap to enable in Settings     ↗
```

- Icon color: `AppColors.warning` (#F59E0B)
- Subtitle color: `AppColors.warning`
- Tap action: `UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)`
- Placement: between subscriptionSection and bankSection in SettingsView
- Never shown for `.notDetermined` (handled in onboarding OB step 16)

---

## Hardcoded Value Prohibition

Every PR touching UI must pass this check:

### Fonts
```swift
// Never
.font(.system(size: 14, weight: .semibold))

// Always
.font(.inlineLabel)
```

### Colors
```swift
// Never
Color.white
Color.white.opacity(0.3)
Color.black.opacity(0.4)

// Always
AppColors.textPrimary
AppColors.overlayWhiteForegroundSoft
AppColors.cardShadow

// Exception: gradient transparent stops only
Color.black.opacity(0)   // allowed
Color.clear              // allowed
```

### Spacing
```swift
// Never
.padding(16)
.padding(.horizontal, 20)
VStack(spacing: 12)

// Always
.padding(AppSpacing.md)
.padding(.horizontal, AppSpacing.cardPadding)
VStack(spacing: AppSpacing.cardGap)
```

### Radius
```swift
// Never
.cornerRadius(12)
.clipShape(RoundedRectangle(cornerRadius: 16))

// Always
.clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
```

---

## Changing the App Typeface

Edit one function in `Style/Typography.swift`:

```swift
// Current: SF Pro
private extension Font {
    static func appFont(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        .system(size: size, weight: weight)
    }
}

// SF Rounded
.system(size: size, weight: weight, design: .rounded)

// Custom font
Font(UIFont(name: "MyFont-Regular", size: size) ?? .systemFont(ofSize: size))
```

`.obQuestion` (Playfair Display) is onboarding-only and not controlled by `appFont()`.

---

## Design System Files

| File | Contents |
|------|----------|
| `Style/Colors.swift` | AppColors — all color tokens |
| `Style/Typography.swift` | Font tokens + AppTypography size constants + appFont() |
| `Style/Spacing.swift` | AppSpacing + AppRadius |

---

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-04-06 | DESIGN.md created | Codified existing system from code — no new decisions, documentation only |
| 2026-04-06 | FIRECountdownCard uses gradient border stroke (1pt) | Visual hierarchy: FIRE card is the hero, all other cards use plain surfaceBorder |
| 2026-04-06 | FIRECountdownCard timeline layout: start date left, FIRE date right | Progress bar = literal journey. More concrete than "N years to go" |
| 2026-04-06 | Both timeline date anchors use MMM d, yyyy | Consistent format at same hierarchy level. Right side is estimate but specific date is more motivating |
| 2026-04-06 | Settings notification entry uses warning color, not error | Notifications off is an attention item, not a failure state |
| 2026-04-06 | Report screens use story/swipe format (not card stack) | One metric per screen eliminates information overload; matches user mental model from Instagram Stories / Spotify Wrapped |
| 2026-04-06 | Hero number at 64pt bold, −2pt kerning (new `.storyHero` token) | Large enough to read at a glance; tight tracking suits numerals at display size |
| 2026-04-06 | Gradient text only for directional FIRE delta; white for neutral values | Gradient carries meaning (progress toward FIRE); using it for all numbers dilutes the signal |
| 2026-04-06 | Distinct radial background accent per story type (purple/green/amber/blue/surface) | Visual landmark — user knows what category they're on without reading the label |
| 2026-04-06 | IssueZeroView story 4 includes primary CTA button; all other stories have no buttons | Issue Zero ends the onboarding loop — needs explicit dismiss. Monthly/Annual reports are informational; swipe-to-dismiss is sufficient |
| 2026-04-06 | AnnualReportView story 2 uses 2×2 stat grid instead of single hero | Annual summary has 4 equally important stats (rate, saved, best month, return); no single metric dominates |
| 2026-04-06 | Shareable screenshot card deferred from v2 | Story format is the priority; `ImageRenderer` export adds complexity without clear user demand at launch |
