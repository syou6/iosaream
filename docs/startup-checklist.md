# OkiMission Startup Checklist

A linear list of one-time setup steps the first developer (you) needs to
complete before iteration becomes routine.  Items are grouped by which can
be done in parallel.

## Day 1 — Open the package and verify it builds

- [ ] Clone the repo on a Mac with Xcode 26 (or the latest beta available).
- [ ] Run `swift build` from the repo root.  All five Swift packages
      should build with no errors.  Compile failures should be filed as
      issues against the relevant module.
- [ ] Run `swift test`.  All Swift Testing suites should pass.

If `swift build` fails on a SwiftData or @ModelActor symbol, your Swift
toolchain is older than Swift 6.0.  Install the matching Xcode beta.

## Week 1 — Accounts and identifiers

These can be done in parallel; none depend on local code.

- [ ] **Apple Developer Program** (¥12,980/year)
      https://developer.apple.com/programs/
- [ ] **Domain registration**: `oki-mission.app` via a registrar
      (お名前.com, Cloudflare Registrar, etc.).  Add a placeholder DNS
      record so SSL provisioning is testable later.
- [ ] **Supabase Pro plan** (~$25/month).  Create a project, pick a
      region close to the user base (Tokyo).  Capture
      `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
- [ ] **RevenueCat** free plan.  Create a project + iOS app; capture the
      public API key.
- [ ] **Google AI Studio** for the Gemini API key.  Enable billing.
- [ ] **PostHog** free plan (EU region recommended).  Capture API key
      and host URL.
- [ ] **Sentry** free plan.  Create an iOS project; capture DSN.
- [ ] **GitHub** repo for the iOS App target — this repo for the
      Swift Package + Supabase backend.

## Week 1–2 — Backend deployment

- [ ] Install the Supabase CLI (`brew install supabase/tap/supabase`).
- [ ] `supabase login`, `supabase link --project-ref <ref>`.
- [ ] `supabase db push` to apply all SQL migrations.
- [ ] Set Edge Function secrets:
      ```
      supabase secrets set GEMINI_API_KEY=...
      supabase secrets set REVENUECAT_WEBHOOK_SECRET=...
      supabase secrets set APNS_TEAM_ID=...
      supabase secrets set APNS_KEY_ID=...
      supabase secrets set APNS_KEY_P8="$(cat AuthKey_XXXX.p8)"
      supabase secrets set APP_BUNDLE_ID=com.yourdomain.OkiMission
      supabase secrets set INTERNAL_RPC_KEY=$(openssl rand -hex 32)
      ```
- [ ] Deploy each Edge Function (`supabase functions deploy missions-generate`
      and so on for the other three).
- [ ] In RevenueCat, configure the webhook URL to point at
      `/functions/v1/billing-webhook` using the `REVENUECAT_WEBHOOK_SECRET`
      you just set.
- [ ] Configure Sign in with Apple in Supabase Auth (Apple Service ID
      and private key from the Apple Developer portal).

## Week 2 — App target

- [ ] Follow `docs/ios-app-target-setup.md` to create the `OkiMission`
      App target inside this repo.
- [ ] Add the local SPM package (`Package.swift` at repo root) to the
      project and link all five libraries.
- [ ] Add the required capabilities and Info.plist entries (see same
      doc).
- [ ] Build for an iPhone 11 simulator first; this catches the bulk of
      issues quickly.

## Week 3 — Live integrations

These can each be picked up independently as time permits.

- [ ] **AlarmKit live adapter** conforming to `AlarmServicing`.  Use
      `InMemoryAlarmService` as the reference for state transitions and
      event semantics.  Verify Xcode 26 ships the AlarmKit entitlement;
      apply if not.
- [ ] **AVCaptureSession + Vision adapters** for `CameraSessioning`,
      `PoseDetecting`, `ObjectDetecting`, `BarcodeScanning`.  Use the
      `Scripted*` stubs as a contract reference.
- [ ] **CoreMotion adapter** for `MotionSensing`.
- [ ] **Supabase auth adapter** for `AuthServicing`, wired to Sign in
      with Apple via the Supabase JS / Swift client.
- [ ] **RevenueCat adapter** for `EntitlementServicing`.  Wrap
      `Purchases.shared.customerInfoStream`.
- [ ] **PostHog adapter** for `AnalyticsTracking` (`@_implementationOnly`
      import to keep PostHog from leaking into the public API surface).
- [ ] **Sentry SDK** for crash reporting.

## Week 4–6 — UI

- [ ] Build the onboarding flow (Sign in with Apple, permission
      requests, locale picker).
- [ ] Build the AlarmList screen using `@Query` against SwiftData.
- [ ] Build the AlarmEditor screen using `AlarmSpec` as the state.
- [ ] Build the MissionRunner screen for each kind.  Reuse the same
      progress bar driven by `MissionExperience.events`.
- [ ] Build the Paywall screen using `EntitlementServicing` offerings.
- [ ] Build Settings (subscription status, account delete, links to
      legal docs).
- [ ] Hook in `AppGlass` and `AppCard` from `OkiMissionDesignSystem`
      throughout.

## Week 6–8 — Legal and store presence

- [ ] Generate Privacy Policy / Terms / Tokushoho HTML pages from the
      `docs/legal/*.md` drafts; host at oki-mission.app.
- [ ] Have a Japanese-licensed attorney review the legal docs (KIYAC is
      cheaper but a one-time human review is recommended).
- [ ] App Store Connect: create the app record, products
      (`com.yourdomain.OkiMission.pro.monthly`,
      `com.yourdomain.OkiMission.pro.yearly`), Family Sharing on,
      introductory offers configured.
- [ ] Privacy Manifest (`PrivacyInfo.xcprivacy`).  See plan §18.2 for
      the required reason codes.
- [ ] App Store Description, screenshots (6.7" / 6.1"), keywords.

## Week 8+ — Beta

- [ ] Build the Beta scheme, upload to TestFlight internal group.
- [ ] Invite ~30 testers, share an in-app feedback form.
- [ ] Iterate; aim for one beta build per week.
- [ ] Submit for App Store review.

## Maintenance loop after launch

- [ ] Watch Sentry crash-free user rate; alert below 99%.
- [ ] Watch PostHog DAU / conversion; investigate week-over-week drops.
- [ ] Rotate Gemini API key every 6 months.
- [ ] Rotate RC webhook secret every 12 months.
- [ ] Quarterly: review billing_events for unprocessed entries.
- [ ] Quarterly: review mission_runs for cheated outliers (potential
      bug reports vs actual misuse).
