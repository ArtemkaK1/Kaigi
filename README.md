# Kaigi

**Your meetings. Your notes. All connected.**

Kaigi (会議, “meeting”) is a native macOS menu bar app for meetings, private occurrence notes and recurring meeting context. Notes use local SwiftData storage, with optional on-device AI.

## Build and run

Use Xcode 26 or newer with the macOS SDK. The app targets macOS 15 or newer; macOS 15 runtime compatibility still requires validation. AI features require macOS 26 or newer, supported Apple Intelligence hardware and language, Apple Intelligence enabled, and a ready model.

Open `Kaigi.xcodeproj`, select the **Kaigi** shared scheme and **My Mac**, then build and run. Local signed builds require a development team and signing identity available to Xcode. The project uses automatic signing.

```sh
xcodebuild -project Kaigi.xcodeproj -scheme Kaigi -configuration Debug build
xcodebuild -project Kaigi.xcodeproj -scheme Kaigi -configuration Release build
xcodebuild -project Kaigi.xcodeproj -scheme Kaigi -destination 'platform=macOS' \
  -parallel-testing-enabled NO test
python3 Tools/verify-architecture.py
python3 Tools/test-transfer-data.py
git diff --check
```

The Swift module remains `Meetrail` to preserve SwiftData model identity; tests use `@testable import Meetrail`.

For a private preview, run a Debug build with `--sample --show-agenda`. This uses synthetic calendars and in-memory notes without requesting calendar access. Add `--onboarding` to preview setup, `--large-text` to check accessibility text sizing, or `-NSAppearance Aqua` / `-NSAppearance DarkAqua` to check appearance. UI tests require an interactive macOS session; live calendar integration tests require the synthetic fixtures described by `Tools/run-calendar-qa.sh` and cleanup afterward.

## Use and capabilities

- A compact, single-day agenda with separate notes and Join actions, labeled conference links, and keyboard navigation. Right-click the menu bar symbol for Settings and Quit Kaigi.
- Occurrence notes with local autosave, revision restoration, Markdown export, and floating editors. Notes from missing calendar events remain recoverable on their original agenda day.
- History & Context for earlier occurrences, manually confirmed recurring context, and explicit carryover. No task owner, deadline, or completion is inferred.
- Optional Clean Up and Structure through Apple Foundation Models. Suggestions require review and Apply; originals remain in revision history. Unsupported languages or unavailable models show an unavailable/error state.
- Optional local reminders that omit private meeting titles and notes, plus launch at login.

Only Apple / System Calendars connects today. Google, Microsoft, and CalDAV accounts already synchronized through macOS are available through EventKit. Calendar access is requested only after an explicit Connect action, and production adapters are read-only. Direct provider connections are labeled Coming Soon; external AI services are not implemented.

Calendar and notification consent, launch-at-login approval, model readiness, and conference links depend on macOS and external services. Synthetic previews do not validate those services.

## Data and compatibility

Notes belong to meeting occurrences and their history. Calendar selection uses stable IDs, retaining intentionally empty selections and temporarily missing calendars. Changed event/calendar identities are kept conservatively separate; matching never relies on titles alone.

Existing Meetrail data is not migrated or removed automatically. Read [the data transfer procedure](Docs/DataMigration.md) before switching. Store initialization failures never reset data. Keep real notes, account data, store backups, and sensitive screenshots outside Git. See [SECURITY.md](SECURITY.md) for storage and privacy limits.

## Architecture

Views → ViewModels → Domain use cases/services → repository/provider protocols → Data/Infrastructure adapters. App composition constructs concrete dependencies and coordinates windows. ViewModels use Foundation/Observation with `@MainActor @Observable`; SwiftData, EventKit, and Foundation Models stay in Data. Infrastructure owns OS export, browser, notification, permission-settings, and login-item adapters. Shared DesignSystem components render values and forward actions.

Calendar providers register through `CalendarAccountCoordinator`. Future provider identities are namespaced by provider, account, and calendar. The [design system](Docs/Brand/DesignSystem.md) documents adaptive purple/neutral colors, native typography, spacing, and controls. Every SwiftUI View modifier starts on its own line.

## License and contribution rights

Copyright © 2026 Artemiy Kirillov. Licensed under [PolyForm Noncommercial 1.0.0](LICENSE.md). Kaigi is source-available; commercial use requires separate authorization. Contributor-rights agreements must be settled before merging outside work intended for commercial redistribution; see [CONTRIBUTING.md](CONTRIBUTING.md). Preserve all copyright/license notices.

No MeetingBar code/assets or third-party package dependencies are used. Provider artwork remains separately owned: preserve the [provider notices](Kaigi/Resources/ProviderArtworkNotices.txt) and bundled Microsoft Fabric Assets license. Apple's Calendar artwork is rendered locally and is not redistributed.
