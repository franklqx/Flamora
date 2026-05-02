# Flamora — Landing Page

Marketing site for Flamora. Lives in the same monorepo as the iOS app, deployed via GitHub Pages.

## Stack
- Single-file HTML, no build
- Tailwind CSS via CDN
- Google Fonts: Playfair Display + Inter

## Local preview
```bash
open landing/index.html
```

## Deploy
Auto-deployed via `.github/workflows/deploy-pages.yml` on every push to `main` that touches `landing/**`.

Live URL (after first deploy): <https://franklqx.github.io/Flamora/>

## Status
🚧 Phase 1 — Waitlist. Email form is a UI mock; will be wired to Supabase + Resend before launch.

## Roadmap
- [ ] Replace SVG mockups with real iPhone screenshots
- [ ] Wire waitlist to Supabase + Resend
- [ ] Add OG image + favicon
- [ ] Switch CTA to App Store badge after launch
