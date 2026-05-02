# FIRE Progress Simulator Prototype Notes

## Source HTML

Current prototype:

`design-reference/fire-progress-simulator-prototype.html`

This file is the saved HTML prototype for the FIRE progress simulator. It is a standalone static prototype with inline CSS and JavaScript. Open it directly in a browser with:

```bash
open "/Users/frankli/Desktop/关羽与吕布/Flamora app/design-reference/fire-progress-simulator-prototype.html"
```

The source file is intentionally kept as the canonical HTML artifact instead of embedding all 895 lines again in this note. This document records what the HTML contains and how it was written so the design can be implemented in SwiftUI later.

## Product Intent

This screen is not a generic FIRE calculator. It is the user's current FIRE forecast based on Flamora's Budget Setup result.

The page should answer:

1. When does the current plan reach FIRE?
2. What is the user's FIRE progress today?
3. If the user changes monthly investment or retirement spending, how does the FIRE date move?

The default state is current forecast only. Scenario comparison appears only after the user moves a control.

## Data Needed

Baseline data should come from Budget Setup / active plan:

- `currentAge`
- `startingPortfolioBalance` or current invested assets
- `savingsTargetMonthly`
- `retirementSpendingMonthly`
- `expectedReturn`
- `withdrawalRate`
- `fireNumber`
- `officialFireDate`
- `officialFireAge`

User-adjustable scenario inputs:

- Monthly investment
- Monthly retirement spending

Advanced assumptions remain visible but not primary controls:

- Current age
- Invested assets
- Expected return
- Withdrawal rate

## Screen Structure

The HTML is organized into these sections:

- `hero`: headline and supporting copy around the user's current FIRE forecast.
- `summary`: three cards for FIRE date, FIRE age, and progress.
- `chart-card`: projection chart from today until the FIRE point.
- `controls`: two scenario controls, monthly investment and retirement spending.
- `calc-card`: small read-only block showing inputs used for the calculation.

Relevant source anchors:

- Hero starts around `fire-progress-simulator-prototype.html:585`
- Summary starts around `fire-progress-simulator-prototype.html:591`
- Chart starts around `fire-progress-simulator-prototype.html:606`
- Controls start around `fire-progress-simulator-prototype.html:669`
- Baseline data starts around `fire-progress-simulator-prototype.html:717`
- FIRE math starts around `fire-progress-simulator-prototype.html:734`

## Chart Behavior

The chart is deliberately simple:

- It shows the current forecast line by default.
- It shows a scenario line only after the user changes a scenario input.
- The curve stops when it reaches FIRE. It does not continue above the FIRE zone.
- The x-axis uses age labels, not “years from now.”
- A soft `FIRE zone` replaces a hard horizontal target line.
- Scenario/current comparison is shown below the chart as simple result cards, not overlapping labels.

This avoids the problems from previous iterations:

- Hard target line looked visually uncomfortable.
- Labels overlapped when scenario and current ages were close.
- Lines continuing after FIRE made the goal ambiguous.
- A fixed-year x-axis made late FIRE dates unreadable.

## Calculation Model Used In The Prototype

The prototype uses the standard FIRE number formula:

```text
FIRE number = retirement monthly spending * 12 / withdrawal rate
```

It estimates months to FIRE using compound growth:

```text
monthlyRate = expectedAnnualReturn / 12
portfolio grows by:
portfolio = portfolio * (1 + monthlyRate) + monthlyInvestment
```

In the HTML, the equivalent function is:

```js
const monthsToFire = (monthlySave, monthlySpend) => {
  const target = fireNumber(monthlySpend);
  if (baseline.assets >= target) return 0;
  const r = baseline.annualReturn / 12;
  const num = target * r + monthlySave;
  const den = baseline.assets * r + monthlySave;
  if (den <= 0 || num <= 0) return Infinity;
  return Math.log(num / den) / Math.log(1 + r);
};
```

The chart series uses the same assumptions and stops at the FIRE crossing:

```js
const buildSeries = (monthlySave, monthlySpend, fireMonths) => {
  const target = fireNumber(monthlySpend);
  const points = [];
  const step = fireMonths > 300 ? 12 : 6;
  for (let month = 0; month < fireMonths; month += step) {
    points.push({ month, ratio: Math.min(1, valueAtMonth(monthlySave, month) / target) });
  }
  points.push({ month: fireMonths, ratio: 1 });
  return points;
};
```

## Visual Direction

The prototype follows the current Flamora dark hero language:

- Deep blue/purple background
- Light glass cards
- Soft white text
- Flamora fire gradient for scenario emphasis

Fire gradient values:

```css
--fire-start: #a78bfa;
--fire-mid: #fca5a5;
--fire-end: #fcd34d;
--fire-gradient: linear-gradient(90deg, #a78bfa 0%, #fca5a5 56%, #fcd34d 100%);
```

Typography should stay lighter than earlier drafts. Avoid heavy 800+ weights in this screen. The prototype mostly uses 520-650 font weights.

## How To Implement In SwiftUI

Use existing simulator data from `preview-simulator` where possible:

- `official_fire_date`
- `official_fire_age`
- `preview_fire_date`
- `preview_fire_age`
- `preview_fire_number`
- `delta_months`
- `official_path`
- `adjusted_path`
- `effective_inputs`

Recommended UI state:

- Store the first loaded official input snapshot.
- Show only current forecast when scenario inputs match official snapshot.
- Show scenario line/result only when the user changes monthly investment or retirement spending.
- Debounce API refresh while sliders move.
- Keep advanced assumptions read-only or collapsed unless the user explicitly opens them.

Recommended SwiftUI components:

- `FireForecastHero`
- `FireSummaryCards`
- `FireForecastChart`
- `ScenarioControls`
- `CalculationInputsCard`

Chart implementation notes:

- Normalize y to FIRE progress ratio, `netWorth / fireNumber`.
- Cap the drawn path at ratio `1.0`.
- Stop drawing each line at its FIRE month.
- Use dynamic x-axis horizon:

```text
horizonMonths = ceil((max(currentFireMonths, scenarioFireMonths) + 24) / 12) * 12
```

- Render age labels:

```text
start age = currentAge
mid age = currentAge + horizonYears / 2
end age = currentAge + horizonYears
```

## Current Prototype Status

Status: saved as HTML and documented.

Validation performed:

```bash
node -e "const fs=require('fs'); const html=fs.readFileSync('design-reference/fire-progress-simulator-prototype.html','utf8'); const script=html.match(/<script>([\\s\\S]*)<\\/script>/)[1]; new Function(script); console.log('script syntax ok')"
```

Result: script syntax ok.


## Full HTML Snapshot

This is the full saved HTML source from `design-reference/fire-progress-simulator-prototype.html` at the time this note was written.

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Flamora FIRE Progress Simulator</title>
<style>
  :root {
    --ink: #111827;
    --hero-a: #15162a;
    --hero-b: #26306c;
    --hero-c: #7087ea;
    --white: rgba(255,255,255,0.96);
    --soft: rgba(255,255,255,0.70);
    --muted: rgba(255,255,255,0.46);
    --line: rgba(255,255,255,0.13);
    --panel: rgba(255,255,255,0.085);
    --panel-2: rgba(255,255,255,0.12);
    --fire-start: #a78bfa;
    --fire-mid: #fca5a5;
    --fire-end: #fcd34d;
    --fire-gradient: linear-gradient(90deg, #a78bfa 0%, #fca5a5 56%, #fcd34d 100%);
    --gold: #fcd34d;
    --blue: #93c5fd;
    --green: #34d399;
  }

  * { box-sizing: border-box; }

  body {
    margin: 0;
    min-height: 100vh;
    display: grid;
    place-items: start center;
    padding: 28px 14px;
    background: linear-gradient(180deg, #f7f8fb, #edf1f8);
    font-family: "SF Pro Text", "SF Pro Display", -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
    color: var(--ink);
  }

  button, input { font: inherit; }

  .wrap { width: min(430px, 100%); }

  .meta {
    display: flex;
    justify-content: space-between;
    padding: 0 8px 10px;
    color: rgba(17,24,39,0.58);
    font-size: 13px;
  }

  .phone {
    padding: 14px;
    border-radius: 52px;
    background: linear-gradient(180deg, rgba(255,255,255,0.82), rgba(255,255,255,0.38));
    border: 1px solid rgba(255,255,255,0.88);
    box-shadow: 0 30px 84px rgba(31,40,74,0.16);
  }

  .screen {
    position: relative;
    height: 892px;
    overflow: hidden;
    border-radius: 38px;
    background:
      radial-gradient(circle at 18% 5%, rgba(196,181,253,0.20), transparent 24%),
      radial-gradient(circle at 82% 10%, rgba(167,139,250,0.22), transparent 27%),
      linear-gradient(180deg, var(--hero-a) 0%, var(--hero-b) 40%, var(--hero-c) 100%);
  }

  .scroll {
    position: absolute;
    inset: 0;
    overflow-y: auto;
    padding: 18px 18px 104px;
    scrollbar-width: none;
  }
  .scroll::-webkit-scrollbar { display: none; }

  .status {
    height: 34px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    color: var(--white);
    font-size: 13px;
    font-weight: 600;
  }

  .island {
    width: 108px;
    height: 30px;
    border-radius: 999px;
    background: rgba(8,10,18,0.96);
  }

  .topbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin: 12px 0 22px;
  }

  .brand {
    display: inline-flex;
    align-items: center;
    gap: 10px;
    color: var(--white);
    font-size: 14px;
    font-weight: 650;
  }

  .mark, .close {
    width: 38px;
    height: 38px;
    display: grid;
    place-items: center;
    border-radius: 999px;
    background: rgba(255,255,255,0.09);
    border: 1px solid rgba(255,255,255,0.14);
    color: var(--white);
  }

  .close {
    border: 0;
    cursor: pointer;
  }

  .flame {
    width: 14px;
    height: 19px;
    border-radius: 11px 11px 12px 12px;
    background: linear-gradient(180deg, var(--gold), #fca5a5 52%, #a78bfa);
    transform: rotate(8deg);
  }

  .hero {
    margin-bottom: 14px;
  }

  .eyebrow {
    margin-bottom: 8px;
    color: var(--muted);
    font-size: 11px;
    font-weight: 650;
    letter-spacing: 0.12em;
    text-transform: uppercase;
  }

  h1 {
    margin: 0 0 8px;
    color: var(--white);
    font-size: 31px;
    line-height: 1.08;
    font-weight: 620;
    letter-spacing: 0;
  }

  h1 span {
    background: var(--fire-gradient);
    -webkit-background-clip: text;
    background-clip: text;
    color: transparent;
  }

  .hero p {
    margin: 0;
    color: var(--soft);
    font-size: 14px;
    line-height: 1.45;
  }

  .summary {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 8px;
    margin-bottom: 12px;
  }

  .summary-card {
    min-height: 72px;
    padding: 11px 10px;
    border-radius: 16px;
    background: var(--panel);
    border: 1px solid var(--line);
  }

  .summary-card strong {
    display: block;
    color: var(--white);
    font-size: 15px;
    line-height: 1.1;
    font-weight: 620;
    font-variant-numeric: tabular-nums;
  }

  .summary-card span {
    display: block;
    margin-top: 7px;
    color: var(--muted);
    font-size: 10px;
    font-weight: 620;
    letter-spacing: 0.08em;
    text-transform: uppercase;
  }

  .chart-card, .controls, .calc-card {
    border-radius: 22px;
    background: linear-gradient(145deg, rgba(255,255,255,0.10), rgba(255,255,255,0.055));
    border: 1px solid var(--line);
    backdrop-filter: blur(22px);
  }

  .chart-card {
    padding: 15px 14px 14px;
    margin-bottom: 12px;
  }

  .section-head {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 12px;
    margin-bottom: 8px;
  }

  .title {
    color: var(--muted);
    font-size: 11px;
    font-weight: 620;
    letter-spacing: 0.12em;
    text-transform: uppercase;
  }

  .legend {
    display: flex;
    align-items: center;
    gap: 10px;
    color: var(--soft);
    font-size: 11px;
  }

  .legend span {
    display: inline-flex;
    align-items: center;
    gap: 5px;
  }

  .legend i {
    width: 17px;
    height: 2px;
    display: inline-block;
    border-radius: 999px;
  }

  .legend .current { background: var(--blue); }
  .legend .scenario { background: var(--fire-gradient); }

  .chart-wrap {
    border-radius: 18px;
    background: rgba(5,7,22,0.18);
    border: 1px solid rgba(255,255,255,0.07);
    overflow: hidden;
  }

  svg {
    display: block;
    width: 100%;
    height: 272px;
  }

  .grid { stroke: rgba(255,255,255,0.075); stroke-width: 1; }
  .fire-zone { fill: url(#fireZone); opacity: 0.9; }
  .current-line { fill: none; stroke: var(--blue); stroke-width: 2.5; stroke-linecap: round; stroke-linejoin: round; }
  .scenario-line { fill: none; stroke: url(#fireStroke); stroke-width: 2.4; stroke-linecap: round; stroke-linejoin: round; opacity: 0; transition: opacity 160ms ease; }
  .scenario-line.visible { opacity: 1; }
  .axis { fill: rgba(255,255,255,0.48); font-size: 11px; font-weight: 520; }
  .dot-current { fill: var(--blue); stroke: rgba(5,7,22,0.55); stroke-width: 2; }
  .dot-scenario { fill: var(--fire-mid); stroke: rgba(5,7,22,0.55); stroke-width: 2; opacity: 0; transition: opacity 160ms ease; }
  .dot-scenario.visible { opacity: 1; }
  .pin-current { stroke: rgba(147,197,253,0.54); stroke-width: 1; stroke-dasharray: 3 5; }
  .pin-scenario { stroke: rgba(252,165,165,0.66); stroke-width: 1; stroke-dasharray: 3 5; opacity: 0; transition: opacity 160ms ease; }
  .pin-scenario.visible { opacity: 1; }
  .fire-label-pill {
    fill: rgba(9,11,28,0.76);
    stroke: rgba(252,165,165,0.22);
  }
  .fire-label-text {
    fill: rgba(255,255,255,0.86);
    font-size: 11px;
    font-weight: 580;
  }

  .chart-note {
    display: grid;
    gap: 7px;
    margin-top: 10px;
  }

  .fire-timeline {
    margin-top: 10px;
    padding: 13px 12px 12px;
    border-radius: 16px;
    background: rgba(255,255,255,0.06);
    border: 1px solid rgba(255,255,255,0.08);
    display: none;
  }

  .fire-timeline.visible {
    display: block;
  }

  .compare-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 8px;
  }

  .compare-item {
    min-height: 58px;
    padding: 10px;
    border-radius: 15px;
    background: rgba(255,255,255,0.06);
    border: 1px solid rgba(255,255,255,0.08);
  }

  .compare-item span {
    display: block;
    margin-bottom: 6px;
    color: var(--muted);
    font-size: 10px;
    font-weight: 620;
    letter-spacing: 0.08em;
    text-transform: uppercase;
  }

  .compare-item strong {
    display: block;
    color: var(--white);
    font-size: 15px;
    line-height: 1.1;
    font-weight: 620;
    font-variant-numeric: tabular-nums;
  }

  .timeline-summary {
    margin-top: 10px;
    color: var(--white);
    font-size: 13px;
    line-height: 1.35;
    text-align: center;
  }

  .timeline-summary strong {
    font-weight: 620;
    background: var(--fire-gradient);
    -webkit-background-clip: text;
    background-clip: text;
    color: transparent;
  }

  .note-row {
    display: flex;
    justify-content: space-between;
    gap: 12px;
    padding: 10px 11px;
    border-radius: 15px;
    background: rgba(255,255,255,0.06);
    border: 1px solid rgba(255,255,255,0.08);
    color: var(--soft);
    font-size: 13px;
  }

  .note-row strong {
    color: var(--white);
    font-weight: 600;
    white-space: nowrap;
    font-variant-numeric: tabular-nums;
  }

  .scenario-result {
    padding: 11px 12px;
    border-radius: 15px;
    background:
      linear-gradient(135deg, rgba(167,139,250,0.16), rgba(252,165,165,0.13) 54%, rgba(252,211,77,0.10));
    border: 1px solid rgba(252,165,165,0.26);
    color: var(--white);
    font-size: 13px;
    line-height: 1.38;
  }

  .scenario-result strong {
    font-weight: 620;
    background: var(--fire-gradient);
    -webkit-background-clip: text;
    background-clip: text;
    color: transparent;
  }

  .controls {
    padding: 15px;
    margin-bottom: 12px;
  }

  .intro {
    margin: 5px 0 13px;
    color: var(--soft);
    font-size: 13px;
    line-height: 1.4;
  }

  .control {
    padding: 12px;
    border-radius: 17px;
    background: rgba(255,255,255,0.06);
    border: 1px solid rgba(255,255,255,0.09);
  }

  .control + .control { margin-top: 10px; }

  .control-top {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 12px;
    margin-bottom: 10px;
  }

  .control-name {
    color: var(--white);
    font-size: 14px;
    font-weight: 600;
  }

  .control-sub {
    margin-top: 4px;
    color: var(--muted);
    font-size: 11px;
  }

  .value {
    min-width: 92px;
    color: var(--white);
    text-align: right;
    font-size: 14px;
    font-weight: 600;
    font-variant-numeric: tabular-nums;
  }

  input[type="range"] {
    width: 100%;
    height: 30px;
    margin: 0;
    appearance: none;
    background: transparent;
  }

  input[type="range"]::-webkit-slider-runnable-track {
    height: 5px;
    border-radius: 999px;
    background: var(--fire-gradient);
  }

  input[type="range"]::-webkit-slider-thumb {
    appearance: none;
    width: 22px;
    height: 22px;
    margin-top: -8.5px;
    border-radius: 999px;
    background: #fff;
    border: 3px solid var(--fire-mid);
    box-shadow: 0 5px 16px rgba(0,0,0,0.24);
  }

  .calc-card {
    padding: 14px;
  }

  .calc-grid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 7px;
    margin-top: 10px;
  }

  .calc {
    min-height: 50px;
    padding: 9px 6px;
    border-radius: 14px;
    background: rgba(255,255,255,0.055);
    border: 1px solid rgba(255,255,255,0.075);
  }

  .calc strong {
    display: block;
    color: var(--white);
    font-size: 12px;
    font-weight: 600;
    text-align: center;
    font-variant-numeric: tabular-nums;
  }

  .calc span {
    display: block;
    margin-top: 5px;
    color: var(--muted);
    font-size: 9px;
    font-weight: 520;
    text-align: center;
    text-transform: uppercase;
  }

  .tabbar {
    position: absolute;
    left: 40px;
    right: 40px;
    bottom: 22px;
    height: 64px;
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 8px;
    align-items: center;
    padding: 8px;
    border-radius: 999px;
    background: rgba(255,255,255,0.64);
    border: 1px solid rgba(255,255,255,0.86);
    box-shadow: 0 18px 48px rgba(40,52,92,0.18);
    backdrop-filter: blur(26px);
  }

  .tab {
    height: 48px;
    border: 0;
    border-radius: 999px;
    background: transparent;
    color: rgba(17,24,39,0.5);
    font-size: 12px;
    font-weight: 650;
  }

  .tab.active {
    background: rgba(17,24,39,0.92);
    color: #fff;
  }

  @media (max-width: 460px) {
    body { padding: 12px 8px 24px; }
    .phone { padding: 8px; border-radius: 38px; }
    .screen { height: 852px; border-radius: 30px; }
    .scroll { padding-inline: 12px; }
    .summary { grid-template-columns: 1fr; }
    .calc-grid { grid-template-columns: repeat(2, 1fr); }
  }
</style>
</head>
<body>
  <main class="wrap">
    <div class="meta">
      <span><strong>Flamora</strong> FIRE progress</span>
      <span>Prototype</span>
    </div>

    <div class="phone">
      <div class="screen">
        <div class="scroll">
          <div class="status">
            <span>9:41</span>
            <span class="island"></span>
            <span>100%</span>
          </div>

          <div class="topbar">
            <div class="brand">
              <span class="mark"><span class="flame"></span></span>
              <span>Flamora</span>
            </div>
            <button class="close" aria-label="Close">
              <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true">
                <path d="M6 6l12 12M18 6L6 18" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round"/>
              </svg>
            </button>
          </div>

          <section class="hero">
            <div class="eyebrow">Your FIRE forecast</div>
            <h1 id="headline">You’re on track to FIRE at <span>45</span></h1>
            <p id="subhead">Based on your Budget Setup plan and current invested assets.</p>
          </section>

          <section class="summary" aria-label="Current FIRE summary">
            <div class="summary-card">
              <strong id="fireDate">Feb 2038</strong>
              <span>FIRE date</span>
            </div>
            <div class="summary-card">
              <strong id="fireAge">Age 45</strong>
              <span>FIRE age</span>
            </div>
            <div class="summary-card">
              <strong id="progress">16%</strong>
              <span>Progress</span>
            </div>
          </section>

          <section class="chart-card" aria-label="Current FIRE forecast chart">
            <div class="section-head">
              <div class="title">Forecast path</div>
              <div class="legend">
                <span><i class="current"></i>Current</span>
                <span id="scenarioLegend"><i class="scenario"></i>Scenario</span>
              </div>
            </div>

            <div class="chart-wrap">
              <svg viewBox="0 0 360 272" role="img" aria-label="FIRE forecast path from today to target">
                <defs>
	                  <linearGradient id="fireStroke" x1="0" x2="1" y1="0" y2="0">
	                    <stop offset="0" stop-color="#a78bfa"/>
	                    <stop offset="0.56" stop-color="#fca5a5"/>
	                    <stop offset="1" stop-color="#fcd34d"/>
	                  </linearGradient>
	                  <linearGradient id="fireZone" x1="0" x2="0" y1="0" y2="1">
	                    <stop offset="0" stop-color="#fca5a5" stop-opacity="0.18"/>
	                    <stop offset="1" stop-color="#fca5a5" stop-opacity="0"/>
	                  </linearGradient>
	                </defs>
	                <g id="grid"></g>
	                <rect id="fireZoneRect" class="fire-zone"></rect>
	                <g id="fireLabel">
	                  <rect class="fire-label-pill" rx="13" width="82" height="26"></rect>
	                  <text class="fire-label-text" x="41" y="17" text-anchor="middle">FIRE zone</text>
	                </g>
	                <path id="currentPath" class="current-line"></path>
                <path id="scenarioPath" class="scenario-line"></path>
                <line id="currentPin" class="pin-current"></line>
                <line id="scenarioPin" class="pin-scenario"></line>
                <circle id="currentDot" class="dot-current" r="5"></circle>
                <circle id="scenarioDot" class="dot-scenario" r="5"></circle>
	                <text id="axisStart" class="axis" x="16" y="250">Age 33</text>
	                <text id="axisMid" class="axis" x="176" y="250" text-anchor="middle">Age 43</text>
	                <text id="axisEnd" class="axis" x="314" y="250">Age 53</text>
              </svg>
            </div>

            <div class="chart-note">
              <div class="note-row">
                <span>Current plan</span>
                <strong id="currentResult">Feb 2038 · Age 45</strong>
              </div>
              <div class="scenario-result" id="scenarioResult">Adjust the numbers below to preview a different FIRE date.</div>
            </div>

            <div class="fire-timeline" id="fireTimeline" aria-label="FIRE date difference timeline">
              <div class="compare-grid">
                <div class="compare-item">
                  <span>Scenario</span>
                  <strong id="scenarioCompareAge">Age 49</strong>
                </div>
                <div class="compare-item">
                  <span>Current</span>
                  <strong id="currentCompareAge">Age 52</strong>
                </div>
              </div>
              <div class="timeline-summary" id="timelineSummary">Scenario is <strong>2 years earlier</strong>.</div>
            </div>
          </section>

          <section class="controls" aria-label="Adjust FIRE scenario">
            <div class="title">Adjust scenario</div>
            <p class="intro">Change the two inputs that most affect your FIRE date.</p>

            <article class="control">
              <div class="control-top">
                <div>
                  <div class="control-name">Monthly investment</div>
                  <div class="control-sub">Current plan: $2,200/mo</div>
                </div>
                <div class="value" id="saveValue">$2,200</div>
              </div>
              <input id="save" type="range" min="500" max="10000" step="250" value="2200" aria-label="Monthly investment">
            </article>

            <article class="control">
              <div class="control-top">
                <div>
                  <div class="control-name">Retirement spending</div>
                  <div class="control-sub">Current goal: $6,500/mo</div>
                </div>
                <div class="value" id="spendValue">$6,500</div>
              </div>
              <input id="spend" type="range" min="2500" max="15000" step="250" value="6500" aria-label="Retirement spending">
            </article>
          </section>

          <section class="calc-card" aria-label="Used for calculation">
            <div class="title">Used for calculation</div>
            <div class="calc-grid">
              <div class="calc"><strong>33</strong><span>Age</span></div>
              <div class="calc"><strong>$310K</strong><span>Assets</span></div>
              <div class="calc"><strong>6.0%</strong><span>Return</span></div>
              <div class="calc"><strong>4.0%</strong><span>WR</span></div>
            </div>
          </section>
        </div>

        <nav class="tabbar" aria-label="Main navigation">
          <button class="tab active">Home</button>
          <button class="tab">Cash Flow</button>
          <button class="tab">Invest</button>
        </nav>
      </div>
    </div>
  </main>

<script>
  const baseline = {
    age: 33,
    assets: 310000,
    save: 2200,
    spend: 6500,
    annualReturn: 0.06,
    withdrawalRate: 0.04
  };

  const money = (value) => new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: 0
  }).format(value);

  const fireNumber = (monthlySpend) => monthlySpend * 12 / baseline.withdrawalRate;

  const monthsToFire = (monthlySave, monthlySpend) => {
    const target = fireNumber(monthlySpend);
    if (baseline.assets >= target) return 0;
    const r = baseline.annualReturn / 12;
    const num = target * r + monthlySave;
    const den = baseline.assets * r + monthlySave;
    if (den <= 0 || num <= 0) return Infinity;
    return Math.log(num / den) / Math.log(1 + r);
  };

  const formatAge = (months) => `Age ${Math.round(baseline.age + months / 12)}`;

  const formatAgeNumber = (months) => String(Math.round(baseline.age + months / 12));

  const formatDate = (months) => {
    const d = new Date();
    d.setMonth(d.getMonth() + Math.max(0, Math.round(months)));
    return d.toLocaleDateString("en-US", { month: "short", year: "numeric" });
  };

  const formatDelta = (months) => {
    const abs = Math.abs(Math.round(months));
    const y = Math.floor(abs / 12);
    const m = abs % 12;
    if (abs < 1) return "same date";
    if (y && m) return `${y} years ${m} months`;
    if (y) return `${y} years`;
    return `${m} months`;
  };

  const valueAtMonth = (monthlySave, month) => {
    const r = baseline.annualReturn / 12;
    let value = baseline.assets;
    for (let i = 0; i < Math.max(0, Math.floor(month)); i += 1) {
      value = value * (1 + r) + monthlySave;
    }
    const partial = month - Math.floor(month);
    if (partial > 0) {
      value = value * (1 + r * partial) + monthlySave * partial;
    }
    return value;
  };

  const buildSeries = (monthlySave, monthlySpend, fireMonths) => {
    const target = fireNumber(monthlySpend);
    const points = [];
    const step = fireMonths > 300 ? 12 : 6;
    for (let month = 0; month < fireMonths; month += step) {
      points.push({ month, ratio: Math.min(1, valueAtMonth(monthlySave, month) / target) });
    }
    points.push({ month: fireMonths, ratio: 1 });
    return points;
  };

  const chart = { left: 16, top: 28, width: 328, height: 196, maxRatio: 1.08, horizon: 180 };

  const point = (month, ratio = 1) => ({
    x: chart.left + (Math.min(chart.horizon, month) / chart.horizon) * chart.width,
    y: chart.top + chart.height - (ratio / chart.maxRatio) * chart.height
  });

  const path = (series) => series.map((p, i) => {
    const pos = point(p.month, p.ratio);
    return `${i === 0 ? "M" : "L"} ${pos.x.toFixed(1)} ${pos.y.toFixed(1)}`;
  }).join(" ");

  const setLine = (id, x1, y1, x2, y2) => {
    const el = document.getElementById(id);
    el.setAttribute("x1", x1);
    el.setAttribute("y1", y1);
    el.setAttribute("x2", x2);
    el.setAttribute("y2", y2);
  };

  const toggleScenario = (show) => {
    document.getElementById("scenarioPath").classList.toggle("visible", show);
    document.getElementById("scenarioDot").classList.toggle("visible", show);
    document.getElementById("scenarioPin").classList.toggle("visible", show);
    document.getElementById("fireTimeline").classList.toggle("visible", show);
    document.getElementById("scenarioLegend").style.opacity = show ? "1" : "0.35";
  };

  const setTimeline = (currentMonths, scenarioMonths, delta, earlier) => {
    document.getElementById("currentCompareAge").textContent = `${formatDate(currentMonths)} · ${formatAge(currentMonths)}`;
    document.getElementById("scenarioCompareAge").textContent = `${formatDate(scenarioMonths)} · ${formatAge(scenarioMonths)}`;
    document.getElementById("timelineSummary").innerHTML = `Scenario is <strong>${formatDelta(delta)} ${earlier ? "earlier" : "later"}</strong>.`;
  };

  const update = () => {
    const save = Number(document.getElementById("save").value);
    const spend = Number(document.getElementById("spend").value);
    const currentMonths = monthsToFire(baseline.save, baseline.spend);
    const scenarioMonths = monthsToFire(save, spend);
    const delta = scenarioMonths - currentMonths;
    const changed = save !== baseline.save || spend !== baseline.spend;
    const earlier = delta < 0;
    const progress = Math.min(99, Math.round((baseline.assets / fireNumber(baseline.spend)) * 100));
    chart.horizon = Math.max(60, Math.ceil((Math.max(currentMonths, scenarioMonths) + 24) / 12) * 12);

    document.getElementById("headline").innerHTML = `You’re on track to FIRE at <span>${formatAgeNumber(currentMonths)}</span>`;
    document.getElementById("fireDate").textContent = formatDate(currentMonths);
    document.getElementById("fireAge").textContent = formatAge(currentMonths);
    document.getElementById("progress").textContent = `${progress}%`;
    document.getElementById("currentResult").textContent = `${formatDate(currentMonths)} · ${formatAge(currentMonths)}`;
    document.getElementById("saveValue").textContent = money(save);
    document.getElementById("spendValue").textContent = money(spend);

    if (changed) {
      document.getElementById("scenarioResult").innerHTML = `Scenario: <strong>${formatDate(scenarioMonths)} · ${formatAge(scenarioMonths)}</strong>. That is <strong>${formatDelta(delta)} ${earlier ? "earlier" : "later"}</strong>.`;
    } else {
      document.getElementById("scenarioResult").textContent = "Adjust the numbers below to preview a different FIRE date.";
    }

    const grid = document.getElementById("grid");
    grid.innerHTML = "";
    for (let i = 0; i < 4; i += 1) {
      const y = chart.top + i * (chart.height / 3);
      const line = document.createElementNS("http://www.w3.org/2000/svg", "line");
      line.setAttribute("x1", chart.left);
      line.setAttribute("x2", chart.left + chart.width);
      line.setAttribute("y1", y);
      line.setAttribute("y2", y);
      line.setAttribute("class", "grid");
      grid.appendChild(line);
    }

    const targetY = point(0, 1).y;
    const zoneTop = chart.top + 10;
    const zoneHeight = Math.max(18, targetY - zoneTop + 12);
    const zone = document.getElementById("fireZoneRect");
    zone.setAttribute("x", chart.left);
    zone.setAttribute("y", zoneTop);
    zone.setAttribute("width", chart.width);
    zone.setAttribute("height", zoneHeight);
    const label = document.getElementById("fireLabel");
    label.setAttribute("transform", `translate(${chart.left + chart.width - 92} ${zoneTop + 7})`);

    document.getElementById("currentPath").setAttribute("d", path(buildSeries(baseline.save, baseline.spend, currentMonths)));
    document.getElementById("scenarioPath").setAttribute("d", path(buildSeries(save, spend, scenarioMonths)));

    const currentPoint = point(currentMonths, 1);
    const scenarioPoint = point(scenarioMonths, 1);
    setLine("currentPin", currentPoint.x, targetY, currentPoint.x, chart.top + chart.height);
    setLine("scenarioPin", scenarioPoint.x, targetY, scenarioPoint.x, chart.top + chart.height);
    document.getElementById("currentDot").setAttribute("cx", currentPoint.x);
    document.getElementById("currentDot").setAttribute("cy", targetY);
    document.getElementById("scenarioDot").setAttribute("cx", scenarioPoint.x);
    document.getElementById("scenarioDot").setAttribute("cy", targetY);
    const horizonYears = Math.round(chart.horizon / 12);
    document.getElementById("axisStart").textContent = `Age ${baseline.age}`;
    document.getElementById("axisMid").textContent = `Age ${baseline.age + Math.round(horizonYears / 2)}`;
    document.getElementById("axisEnd").textContent = `Age ${baseline.age + horizonYears}`;
    setTimeline(currentMonths, scenarioMonths, delta, earlier);
    toggleScenario(changed);
  };

  document.getElementById("save").addEventListener("input", update);
  document.getElementById("spend").addEventListener("input", update);
  update();
</script>
</body>
</html>

```
