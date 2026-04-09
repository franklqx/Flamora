# Flamora Home Prototype — Developer Documentation

**File:** `home-rebuild-glass-prototype.html`
**Last updated:** 2026-04-08
**Purpose:** Interactive HTML/CSS/JS prototype for the Flamora iOS app Home, Cash Flow, and Investment screens. Intended for design review, partner handoff, and native SwiftUI implementation reference.

---

## How to Open

Open in any modern browser (Chrome, Safari, Firefox). No build step, no server needed.

Optionally run a local server for the flame logo to load (it references a relative path):

```bash
cd "design-reference"
python3 -m http.server 7890
# then open http://localhost:7890/home-rebuild-glass-prototype.html
```

---

## Overall Layout

The page has **two columns** inside a `.shell` container:

| Column | Class | Contents |
|---|---|---|
| Left (430px) | `.phone-wrap` | The phone mockup with all interactive UI |
| Right (flexible) | `.notes` | Component board — design notes and mini examples |

On screens narrower than 1080px, the notes column stacks below the phone.

---

## Phone Shell Structure

```
.phone                        ← White glass phone bezel (430 × 920px)
  └── .screen                 ← Inner screen area (892px tall, border-radius 38px)
        ├── .statusbar        ← Fake iOS status bar (time, Dynamic Island, icons)
        ├── .app-view.home-view.active   ← Home tab (visible by default)
        ├── .app-view.cash-view          ← Cash Flow tab (hidden by default)
        ├── .app-view.invest-view        ← Investment tab (hidden by default)
        └── .tabbar                      ← Floating bottom navigation
```

**Key dimensions:**
- Screen total height: 892px
- `.app-view` inset: `top: 48px, bottom: 92px` (leaves room for status bar and tab bar)
- Tab bar bottom offset: 24px from screen bottom
- Phone padding: 14px on all sides

---

## Tab Switching

Each `.app-view` starts with `opacity: 0; pointer-events: none`. The active one gets `.active` class → `opacity: 1; pointer-events: auto`.

The JavaScript `switchView(viewName)` function handles this. It also:
- Expands the tabbar back to full state on every tab switch
- Resets Home's progress to 0 when leaving Home
- Starts/stops Cash card autoplay
- Closes expanded Cash/Invest views when switching away

---

## CSS Design Tokens (`:root` variables)

| Variable | Value | Used for |
|---|---|---|
| `--ink` | `#111827` | Primary text |
| `--ink-soft` | `rgba(17,24,39,0.66)` | Secondary text |
| `--ink-faint` | `rgba(17,24,39,0.42)` | Tertiary / disabled text |
| `--fire-start` | `#a78bfa` | Gradient start (purple) |
| `--fire-middle` | `#fca5a5` | Gradient mid (pink) |
| `--fire-end` | `#fcd34d` | Gradient end (amber) |
| `--fire-gradient` | 90deg purple→pink→amber | Brand strip |
| `--brand-purple-surface` | Multi-layer radial+linear | Dark hero background |
| `--hero-fade` | `var(--brand-purple-surface)` | Home hero background |
| `--shell-bg` | `#f7f8fb → #eef1f7` | Phone inner bezel background |
| `--phone-shadow` | `0 34px 90px rgba(31,40,74,0.16)` | Phone drop shadow |

---

## Tab 1: Home

### Structure

```
.app-view.home-view
  ├── .hero-layer                  ← Dark gradient hero (expands on drag)
  │     ├── .topbar                ← Brand logo + Settings icon
  │     ├── .hero-summary          ← "Your FIRE Journey" text + progress bar
  │     └── .simulator-panel       ← Hidden until drag; contains chart + controls
  │           ├── .sandbox-hero    ← "You will be financially free by age 30"
  │           ├── .sim-graph       ← 16-bar projected growth chart
  │           └── .sim-controls    ← Editable detail rows + Advanced toggle
  └── .sheet                       ← White card (slides down on drag)
        ├── .sheet-handle          ← Visual drag affordance (pill)
        └── .roadmap               ← 3-step setup checklist
```

### The Drag Interaction (setProgress)

The core of the Home tab is a progress value `p` from `0` (default view) to `1` (simulator fully expanded). Every element animates based on this single number.

**State at p=0 (default):**
- Hero is 308px tall
- White sheet is in normal position (overlaps hero bottom by 76px)
- Summary text ("Your FIRE Journey") is visible
- Simulator content is hidden
- Tabbar is full width

**State at p=1 (simulator fully open):**
- Hero fills the entire screen (308 + 452 = 760px)
- White sheet has slid 580px down — completely off screen
- Summary text is gone (opacity 0)
- Sandbox result + chart + detail rows are fully visible
- Tabbar has collapsed into a small ↑ oval button

**Key `setProgress(p)` mappings:**

| Element | Formula |
|---|---|
| `hero-layer` min-height | `308 + (452 × p)` px |
| `hero-layer` border-radius | `0 0 ${22 × (1-p)}px ${22 × (1-p)}px` |
| `hero-summary` opacity | `1 - p` |
| `hero-summary` translateY | `-14 × p` px |
| `sandbox-hero` opacity | `p` |
| `sim-graph` opacity | starts at p=0.16, fully visible at p=1 |
| `sim-controls` opacity | starts at p=0.34, fully visible at p=1 |
| `sheet` translateY | `580 × p` px |
| Tabbar collapses | when `p > 0.72` |

**Drag thresholds:**
- From p=0: drags further down open the simulator. Snaps to p=1 if released at p > 0.76.
- From p=1: drags up close it. Snaps to p=0 if released at p < 0.24.
- Drag travel < 18px is treated as a tap (no transition).

**CSS class `.dragging-sheet`** is added to `.phone` during a drag. This disables all `transition` on `.hero-layer`, `.hero-summary`, `.roadmap`, `.sim-graph`, `.sim-controls`, and `.tabbar` so they track the finger in real time without animation lag.

**`.phone.simulator-mode`** is toggled when `p > 0.02`. This switches `.hero-layer` to full height (`760px`) and enables scrolling inside it.

### Simulator Chart (16-bar graph)

- 16 `<div class="bar">` elements inside `.bar-grid`
- `soft` bars = lighter opacity (early years)
- The active bar (last one by default) shows a callout "label"
- Clicking any bar highlights it and updates the callout and inspector notes
- Each bar has `data-age`, `data-year`, `data-value` attributes

### Simulator Detail Rows

- 4 main rows: Current Age, Monthly Contribution, Current Investment, Retire Monthly Expense
- 3 advanced rows: Expected Return, Inflation, Withdrawal Rate (hidden in `.advanced-block`)
- Clicking a row switches it to edit mode (shows an `<input>` instead of the value button)
- Pressing Enter or blurring commits the new value

### Roadmap (White Sheet Content)

3 step items inside `.step-list`:
1. Set your FIRE goal
2. Connect your accounts
3. Choose your path

Each has a numbered circle, copy, and a chevron arrow. Clicking highlights the step and updates the inspector panel on the right.

---

## Tab 2: Cash Flow

### Structure

```
.app-view.cash-view
  ├── .cash-hero                  ← Dark gradient hero (308px default / 860px expanded)
  │     ├── .topbar               ← Brand logo + Settings icon
  │     ├── .cash-hero-top        ← "Cash Flow" title + "$3,420 spent this month"
  │     └── .cash-tx-panel        ← Hidden until expanded; Apple Wallet card stack
  │           └── .tx-section
  │                 └── .tx-deck  ← 8 transaction cards stacked with negative margin
  └── .cash-sheet                 ← White card (slides to 800px below screen when expanded)
        ├── .cash-sheet-handle    ← Drag affordance
        ├── .cash-stage           ← Rotating spending/saving card carousel
        │     ├── .cash-flow-card.active   ← Spending overview
        │     └── .cash-flow-card.back     ← Saving overview (rotates in after 3.2s)
        └── .cash-flow-cta        ← "Connect accounts" button
```

### Cash Expand/Collapse (openCash / closeCash)

**When opened (`openCash()`):**
1. Adds `.cash-expanded` to `.cash-view`
2. CSS transitions `.cash-hero` from `min-height: 308px` → `860px`
3. CSS transitions `.cash-sheet` from normal position → `translateY(800px)` (off screen)
4. CSS reveals `.cash-tx-panel` (opacity 0→1, max-height 0→800px)
5. CSS applies scroll-fade mask to `.cash-hero` (cards fade as you scroll up)
6. JS stagger-animates each `.tx-card-wrap` into view (`.tx-entered` class added with 50ms delays)
7. Tabbar collapses to ↑ oval after 180ms delay

**When closed (`closeCash()`):**
1. Removes `.cash-expanded`
2. All CSS transitions reverse
3. `.tx-entered` removed from all cards
4. Tabbar expands back to full

**Trigger methods:**
- Click the `.cash-sheet-handle` pill
- Drag the handle down >44px (opens) or up >44px (closes)
- Click the ↑ oval tabbar button

### Apple Wallet Transaction Card Stack

8 cards, each in a `.tx-card-wrap` wrapper.

**The stacking effect:**
- Each `.tx-card-wrap` has `margin-bottom: -102px` — this is what creates the stacking. Cards overlap each other. The last card has `margin-bottom: 0` so it doesn't pull content up.
- `z-index: calc(var(--idx) + 1)` — higher-indexed cards stack on top
- Each card is `height: 148px`. Peek amount = `148 - 102 = 46px` per card

**Entrance animation:**
- Cards start at `opacity: 0; transform: translateY(28px) scale(0.95)`
- Getting `.tx-entered` transitions them to `opacity: 1; transform: translateY(0) scale(1)`
- Staggered with 50–60ms delays per card

**Card internals (each `.tx-card`):**
- Height: 148px, border-radius: 22px
- Background: `rgba(255,255,255,0.68)` + `backdrop-filter: blur(24px) saturate(160%)`
- `--card-rgb` CSS variable per card sets the accent color (icon bg, category pill)
- `::before` pseudo — diagonal gloss highlight
- `::after` pseudo — bottom tint using the card's `--card-rgb` color

**Per-card layout (flex column, space-between):**
- `.tx-icon` — 40×40px rounded square with brand logo or emoji
- `.tx-merchant-info` — merchant name + date stacked
- `.tx-amount-block` — amount + category pill

**Current 8 cards:**

| # | Merchant | Amount | Category | --card-rgb |
|---|---|---|---|---|
| 0 | Netflix | -$22.99 | Entertainment | 190,18,60 (red) |
| 1 | Whole Foods | -$89.43 | Groceries | 21,128,61 (green) |
| 2 | Uber | -$14.50 | Transport | 29,78,216 (blue) |
| 3 | Adobe CC | -$54.99 | Software | 124,58,237 (purple) |
| 4 | Starbucks | -$7.80 | Coffee | 180,83,9 (orange) |
| 5 | Amazon | -$143.20 | Shopping | 15,118,110 (teal) |
| 6 | Equinox | -$185.00 | Health | 14,116,144 (cyan) |
| 7 | Spotify | -$11.99 | Music | 29,185,84 (spotify green) |

**Scroll fade mask on the hero:**
When expanded, `.cash-hero` gets a CSS mask-image that fades cards as they scroll off the top:
```css
mask-image: linear-gradient(to bottom, transparent 0px, rgba(0,0,0,0.6) 44px, black 88px);
```
The top 44px is invisible, then fades in. Cards scrolling upward appear to dissolve.

### Cash Flow Card Carousel (White Sheet)

Two `.cash-flow-card` articles inside `.cash-stage`:
1. **Spending** — $3,420 total / Needs vs Wants breakdown with progress bars
2. **Saving** — $20,200 total / 10-month bar chart / target rate stats

**Auto-rotation:** `startCashAutoplay()` sets a 3.2s interval cycling through cards. One card gets `.active`, the other gets `.back`. CSS animates position and opacity. The carousel stops when leaving the Cash tab.

---

## Tab 3: Investment

### Structure

```
.app-view.invest-view
  ├── .invest-hero                  ← Dark gradient hero (308px / 860px expanded)
  │     ├── .topbar                 ← Brand logo + Settings
  │     ├── .invest-hero-top        ← "Investment" title + $210,150 + +13.8%
  │     └── .invest-chart-panel     ← Hidden until expanded; line chart + period selector
  │           ├── .invest-inline-chart  ← SVG line chart, animated draw-on
  │           └── .invest-inline-periods  ← 1W / 1M / 3M / YTD / All tabs
  └── .invest-sheet                 ← White card (slides to 800px below when expanded)
        ├── .invest-sheet-handle    ← Drag affordance
        ├── .invest-holdings        ← 3-row portfolio list
        │     ├── S&P 500 ETF      $142,800 / +18.2%
        │     ├── Bond Index        $38,400 / +3.4%
        │     └── Cash (HYSA)       $28,950 / +4.8%
        └── .invest-flow-cta        ← "Connect accounts" button
```

### Invest Expand/Collapse (openInvest / closeInvest)

Same pattern as Cash. `openInvest()` adds `.invest-expanded` class, `closeInvest()` removes it.

**When expanded:**
- `.invest-hero` grows to 860px and becomes scrollable
- `.invest-sheet` slides `translateY(800px)` off screen
- `.invest-chart-panel` reveals (opacity 0→1, max-height 0→400px)
- SVG line chart animates its stroke draw (2200ms cubic-bezier)
- Endpoint dot + halo fade in after 2140ms
- Hero uses `display: flex; flex-direction: column; justify-content: center` — so the title + chart are vertically centered in the expanded hero area

### Investment Line Chart Animation

The chart uses SVG `stroke-dasharray` / `stroke-dashoffset` trick:
- `stroke-dasharray: 420` — total path length
- Default: `stroke-dashoffset: 420` — invisible (fully dashed-out)
- On `.invest-expanded`: `stroke-dashoffset: 0` — the line draws from left to right over 2.2s

The endpoint dot and halo circle animate separately with a `2140ms` delay so they appear after the line finishes drawing.

---

## The Tabbar

### Normal State

```
.tabbar
  ├── .tabgrid         ← 3-column grid of tab items
  │     ├── .tab.active[data-tab="home"]   ← Home icon + label
  │     ├── .tab[data-tab="cash"]          ← Cash icon + label
  │     └── .tab[data-tab="invest"]        ← Invest icon + label
  └── .tabbar-up-btn   ← Hidden ↑ arrow (only visible when collapsed)
```

CSS values (normal):
- `left: 26px; width: calc(100% - 52px)` — spans the phone horizontally
- `height: 76px; border-radius: 24px; padding: 9px 10px`
- Glass background: `rgba(255,255,255,0.68)` + `backdrop-filter: blur(28px)`

### Collapsed State (`.tabbar.collapsed`)

When any view is fully expanded (Cash, Invest, or Home simulator), the tabbar collapses into a small oval ↑ button anchored to the bottom-left:

CSS values (collapsed):
- `width: 52px; height: 52px; border-radius: 999px; padding: 0`
- The three tab items fade out (`opacity: 0` on `.tabgrid`)
- The `.tabbar-up-btn` fades in (`opacity: 1`) with a 140ms delay (so it appears after the oval forms)

**Transition properties animated:** `width`, `height`, `border-radius`, `padding` — all over 380ms `cubic-bezier(0.4, 0, 0.2, 1)`.

Note: The tabbar uses `left + width` (not `left + right`) because CSS cannot animate `right: auto`. Width can be transitioned smoothly.

### How Collapse is Triggered

| Tab | Trigger |
|---|---|
| Home | `setProgress()` when `p > 0.72` |
| Cash | `openCash()` after 180ms timeout |
| Invest | `openInvest()` after 180ms timeout |

**Restore:** `collapseTabbar()` / `expandTabbar()` are helper functions. `expandTabbar()` is always called on `switchView()` to reset state when switching tabs.

### The ↑ Up Button

Clicking `.tabbar-up-btn` calls:
- `closeCash()` if on Cash tab
- `closeInvest()` if on Invest tab
- `animateTo(0)` if on Home tab (returns simulator to default)

---

## JavaScript State Variables

| Variable | Type | Purpose |
|---|---|---|
| `currentProgress` | number 0–1 | Home tab simulator progress |
| `dragging` | bool | Whether user is dragging the Home sheet |
| `dragMoved` | bool | Whether the drag has moved >3px (distinguishes tap vs drag) |
| `dragStartY` | number | Y position when drag started |
| `dragStartProgress` | number | Progress value when drag started |
| `dragTravel` | number | Total pixel distance dragged |
| `currentTab` | string | Currently active tab ('home', 'cash', 'invest') |
| `cashExpanded` | bool | Whether Cash hero is expanded |
| `cashDragging` | bool | Whether user is dragging the Cash handle |
| `cashCardIndex` | number | Which Cash card is currently active (0=Spending, 1=Saving) |
| `cashCardTimer` | interval | Auto-rotation timer for Cash cards |
| `investExpanded` | bool | Whether Invest hero is expanded |
| `investDragging` | bool | Whether user is dragging the Invest handle |

---

## Key JavaScript Functions

| Function | What it does |
|---|---|
| `setProgress(p)` | Applies all Home tab animations for a given 0–1 progress value |
| `animateTo(target)` | Smoothly animates `currentProgress` to a target using rAF + cubic easing |
| `collapseTabbar()` | Adds `.collapsed` to tabbar, clears inline styles |
| `expandTabbar()` | Removes `.collapsed` from tabbar, clears inline styles |
| `openCash()` | Expands Cash hero, animates tx cards, collapses tabbar |
| `closeCash()` | Collapses Cash hero, hides tx cards, expands tabbar |
| `openInvest()` | Expands Invest hero, collapses tabbar |
| `closeInvest()` | Collapses Invest hero, expands tabbar |
| `switchView(name)` | Switches active tab, resets relevant states |
| `openSimulator()` | Animates Home to p=1 (full simulator) |
| `closeSimulator()` | Animates Home to p=0 (default) |
| `startCashAutoplay()` | Starts 3.2s card rotation on Cash tab |
| `stopCashAutoplay()` | Clears the rotation interval |
| `renderCashCards()` | Applies `.active`/`.back` to cash carousel cards |

---

## Common Modifications

### Change a transaction card's merchant or amount

Find the `.tx-card-wrap` with the corresponding `--idx` in the HTML (lines ~2490–2600) and update the text inside `.tx-merchant`, `.tx-amount`, `.tx-date`, and `.tx-category-pill`.

To add a new card, copy an existing `.tx-card-wrap` block. Increment `--idx` by 1. The last card should not have a `margin-bottom: -102px` override — the CSS rule `.tx-card-wrap:last-of-type { margin-bottom: 0; }` handles this automatically.

### Change the number of visible cards in the stack

The peek amount per card is controlled by `margin-bottom: -102px`. The card height is `148px`. So visible peek = `148 - 102 = 46px`. To increase or decrease the peek, adjust the negative margin value.

### Change how fast the simulator opens/closes

In `animateTo()`:
```js
const duration = 240; // milliseconds — increase for slower, decrease for faster
```
The easing is `1 - Math.pow(1 - t, 3)` (cubic ease-out).

### Change the Home drag sensitivity

In `moveDrag()`:
```js
setProgress(dragStartProgress + (deltaY / 420));
// 420 = total drag distance in pixels to go from 0 to 1
// Decrease to make it more sensitive, increase for less sensitive
```

### Change when tabbar collapses on Home

In `setProgress()`:
```js
if (p > 0.72) {  // change 0.72 to any threshold between 0 and 1
```

### Change the Cash/Invest card rotation speed

```js
cashCardTimer = setInterval(() => { ... }, 3200); // milliseconds
```

### Change investment portfolio values

In the `.invest-holdings` HTML, update the text inside `.invest-holding-value` and `.invest-holding-change` for each row.

### Add a new tab

1. Add a new `.app-view` section with `data-view="yourname"`
2. Add a `.tab` button to `.tabgrid` with `data-tab="yourname"`
3. Add a case in `switchView()` for the new tab name
4. Handle tabbar expand/collapse in your open/close functions

---

## What Is NOT Implemented (Prototype Limitations)

- No real data — all numbers are hardcoded placeholder values
- The FIRE simulator does not actually recalculate when you edit values
- Bar chart does not redraw when detail row inputs are changed
- No persistence — refreshing the page resets all state
- The investment period buttons (1W / 1M / 3M / YTD / All) do not actually change the chart data
- The logo image requires a local server to load (`../Flamora app/Assets.xcassets/...`)
- No swipe gesture to switch tabs (only tap)

---

## File Size Reference

The file is self-contained: one HTML file, no external CSS or JS dependencies. The only external calls are Clearbit logo lookups (`https://logo.clearbit.com/...`) which fall back to emoji on failure.

---

## Handoff Checklist for SwiftUI Implementation

- [ ] **Home hero background** — multi-layer radial gradients, see `--brand-purple-surface` in `:root`
- [ ] **Home drag sheet** — `setProgress()` drives every element; replicate with SwiftUI `DragGesture` + `@State var progress: CGFloat`
- [ ] **Simulator bar chart** — 16 bars with `height` proportional to investment value, tap to select
- [ ] **Detail row inline editor** — tap shows a text field in-place
- [ ] **Cash hero expand** — toggle between 308px and full-screen; white sheet slides below viewport
- [ ] **Apple Wallet card stack** — negative vertical offset (`margin-bottom: -102px` equiv = `offset(y: -102)` in SwiftUI ZStack)
- [ ] **TX card entrance animation** — staggered `opacity` + `offset` transition per card
- [ ] **Cash scroll-fade mask** — SwiftUI `mask` with a linear gradient for the top fade
- [ ] **Tabbar collapse** — animate width + height + cornerRadius simultaneously; show ↑ button overlay
- [ ] **Invest line chart draw** — SVG stroke-dashoffset → SwiftUI Path with `trim(from:to:)` animated
- [ ] **Card carousel (Cash sheet)** — two cards, auto-switch every 3.2s, cross-fade
