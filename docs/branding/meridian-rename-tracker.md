# Meridian Rename Tracker

This document tracks what has been renamed from `Flamora` to `Meridian`, what is intentionally deferred, and which external systems still need coordination.

## Completed

- App display name changed to `Meridian`.
- Splash wordmark changed from `FLAMORA` to `MERIDIAN`.
- User-facing onboarding, paywall, settings, and landing-page copy updated to `Meridian`.
- OAuth callback scheme changed from `com.flamora.app://auth-callback` to `com.meridian.app://auth-callback`.
- `Info.plist` URL scheme updated to `com.meridian.app`.
- Logger subsystem updated to `com.meridian.app`.
- Bundle identifiers updated:
  - App: `com.meridian.app`
  - Unit tests: `com.meridian.appTests`
  - UI tests: `com.meridian.appUITests`
- Xcode project container renamed to `Meridian.xcodeproj`.
- Xcode-visible internal names updated:
  - app target: `Meridian`
  - unit test target: `MeridianTests`
  - UI test target: `MeridianUITests`
  - shared scheme: `Meridian`
  - app entry file: `MeridianApp.swift`
  - source folders: `Meridian/`, `MeridianTests/`, `MeridianUITests/`
- Current `Meridian` scheme build validated successfully in Xcode CLI.

## Pending External Decisions

- Final website / landing-page domain
  - Needed for privacy-policy and terms links
  - Example future paths:
    - `/privacy`
    - `/terms`
- Supabase Auth redirect URL rollout
  - Confirm `com.meridian.app://auth-callback` has been added in Supabase Auth -> URL Configuration -> Redirect URLs
- App Store Connect legal URL sync
  - Update Privacy Policy URL once the final domain is decided

## Intentionally Deferred

- RevenueCat cleanup
  - Code now recognizes only `Meridian Pro`
  - Old RevenueCat entitlement `Flamora Pro` can be removed from the dashboard once final QA is complete
- Local storage keys
  - `FlamoraStorageKey`
  - Existing `UserDefaults` keys keep the old prefix to avoid breaking existing local state
- Backend / database protocol fields
  - `flamora_category`
  - `flamora_subcategory`
- Info.plist filename
  - Still `Flamora-App-Info.plist`
- Legacy comments / historical docs
  - Older review notes, archived prototypes, and handoff docs still contain `Flamora` where they describe past state

## Follow-Up Work

1. Decide the final public domain.
2. Update legal URLs in app code to the final domain.
3. Finish RevenueCat backend migration from `Flamora Pro` to `Meridian Pro`, then remove code fallback if everything tests cleanly.
4. If local storage keys are migrated later, plan compatibility and rollout carefully.
