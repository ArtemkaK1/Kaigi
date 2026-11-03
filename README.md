# Kaigi

**Your meetings. Your notes. All connected.**

Kaigi (会議, “meeting”) is a native macOS menu bar app for meetings and private occurrence notes. The initial free configuration includes local SwiftData storage, autosave, calendar management, reminders, Markdown export and launch at login.

## Build and run

Use Xcode 26 or newer with the macOS SDK. The app targets macOS 15 or newer; macOS 15 runtime compatibility still requires validation. Internal all-enabled AI testing requires macOS 26 or newer, supported Apple Intelligence hardware and language, Apple Intelligence enabled, and a ready model. AI is unavailable in the free configuration.

Open `Kaigi.xcodeproj`, select the **Kaigi** shared scheme and **My Mac**, then build and run. Local signed builds require a development team and signing identity available to Xcode. The project uses automatic signing.

```sh
xcodebuild -project Kaigi.xcodeproj -scheme Kaigi -configuration Debug build
xcodebuild -project Kaigi.xcodeproj -scheme Kaigi -configuration Release build
xcodebuild -project Kaigi.xcodeproj -scheme Kaigi -destination 'platform=macOS' \
  -parallel-testing-enabled NO test
python3 Tools/verify-architecture.py
python3 Tools/test-transfer-data.py
python3 Tools/test-feature-toggles-release.py
git diff --check
```

The Swift module remains `Meetrail` to preserve SwiftData model identity; tests use `@testable import Meetrail`.

For a private preview, run a Debug build with `--sample --show-agenda`. This uses synthetic calendars and in-memory notes without requesting calendar access, and defaults to the free configuration. Explicitly add `--all-features` to test retained advanced features; this override is accepted only in Debug with `--sample` and is never persisted. Release ignores these overrides. Add `--context-history` for synthetic earlier occurrences, `--mock-ai` for deterministic AI, `--onboarding` to preview setup, `--large-text` to check accessibility text sizing, or `-NSAppearance Aqua` / `-NSAppearance DarkAqua` to check appearance. UI tests require an interactive macOS session and local UI Automation authorization; live calendar integration tests require the synthetic fixtures described by `Tools/run-calendar-qa.sh` and cleanup afterward.

## Use and capabilities

- A compact, single-day agenda with separate notes and Join actions, labeled conference links, and keyboard navigation. Right-click the menu bar symbol for Settings and Quit Kaigi.
- Occurrence notes with local autosave and Markdown export. Notes from missing calendar events remain recoverable on their original agenda day.
- Optional local reminders that omit private meeting titles and notes, plus launch at login.

Only Apple / System Calendars connects today. Google, Microsoft, and CalDAV accounts already synchronized through macOS are available through EventKit. Calendar access is requested only after an explicit Connect action, and production adapters are read-only. Direct provider connections are labeled Coming Soon; external AI services are not implemented.

Calendar and notification consent, launch-at-login approval, model readiness, and conference links depend on macOS and external services. Synthetic previews do not validate those services.

Meeting history, recurring context, AI Clean Up/Structure, revision restoration UI and floating editors are disabled in the initial free configuration. Their source implementations and existing stored context/revisions remain intact. Internal revision creation continues for durability and recovery. See the complete [feature matrix and developer guide](Docs/FeatureToggles.md). This configuration has not been submitted to App Review; runtime toggles alone do not establish compliance with Apple's dormant-functionality rules.

## Data and compatibility

Notes belong to meeting occurrences and their history. Calendar selection uses stable IDs, retaining intentionally empty selections and temporarily missing calendars. Changed event/calendar identities are kept conservatively separate; matching never relies on titles alone.

Existing Meetrail data is not migrated or removed automatically. Read [the data transfer procedure](Docs/DataMigration.md) before switching. Store initialization failures never reset data. Keep real notes, account data, store backups, and sensitive screenshots outside Git. See [SECURITY.md](SECURITY.md) for storage and privacy limits.

## Architecture

Views → ViewModels → Domain use cases/services → repository/provider protocols → Data/Infrastructure adapters. App composition constructs concrete dependencies and coordinates windows. ViewModels use Foundation/Observation with `@MainActor @Observable`; SwiftData, EventKit, and Foundation Models stay in Data. Infrastructure owns OS export, browser, notification, permission-settings, and login-item adapters. Shared DesignSystem components render values and forward actions.

The composition root injects one immutable, typed `FeatureToggles` value into ViewModels, application actions and window coordination. Views render their ViewModel's availability. There are no third-party dependencies, mutable flag services, remote settings, payment state or persisted toggle values.

Calendar providers register through `CalendarAccountCoordinator`. Future provider identities are namespaced by provider, account, and calendar. The [design system](Docs/Brand/DesignSystem.md) documents adaptive purple/neutral colors, native typography, spacing, and controls. Every SwiftUI View modifier starts on its own line.

## Feature-toggle validation — 3 November 2026

On the local MacBook Pro (macOS 26.6.2, Xcode 27 / Swift 6.4), signed Debug and Release builds passed. All 52 unit tests and 18 UI tests passed (70 tests, zero failures or skips in the selected run). The real-calendar fixture integration test was explicitly excluded; no test calendar events or real-note edits were performed. The two synthetic transfer-data tests, architecture checker, Release-selector compilation probe, signature verification and `git diff --check` passed. The optimized Release executable contained none of the Debug override argument markers.

Visual review of synthetic XCTest captures covered free Light/Dark agendas, compact editors with export/Join/autosave, Settings without AI, the all-enabled editor and the enlarged-text bounded scroll viewport. Existing advanced history/context, carryover, revision, floating-editor and AI review tests ran with explicit all-enabled overrides. Test screenshots remain outside Git. The real-model cleanup probe also completed with synthetic input; that is an explicit test and does not enable AI in free mode or establish semantic accuracy.

The first UI attempt timed out awaiting macOS Enable UI Automation authentication; after the owner approved locally, the complete rerun passed. One new revision assertion was corrected to respect the existing 30-second checkpoint-coalescing policy; persistence behavior was not changed. XCTest emitted two internal QoS warnings without test failures. Spoken VoiceOver, macOS 15 runtime validation and live-calendar fixture integration were not rerun. Release UI behavior was established through the shared free-mode UI checks, the actual Release selector probe and binary inspection, rather than opening the owner's production store in a Release UI session. App Review compliance remains unresolved as described in the developer guide; no distribution action was taken.

## License and contribution rights

Copyright © 2026 Artemiy Kirillov. Licensed under [PolyForm Noncommercial 1.0.0](LICENSE.md). Kaigi is source-available; commercial use requires separate authorization. Contributor-rights agreements must be settled before merging outside work intended for commercial redistribution; see [CONTRIBUTING.md](CONTRIBUTING.md). Preserve all copyright/license notices.

No MeetingBar code/assets or third-party package dependencies are used. Provider artwork remains separately owned: preserve the [provider notices](Kaigi/Resources/ProviderArtworkNotices.txt) and bundled Microsoft Fabric Assets license. Apple's Calendar artwork is rendered locally and is not redistributed.
