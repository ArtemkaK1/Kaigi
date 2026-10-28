# Kaigi

**Your meetings. Your notes. All connected.**

Kaigi (会議, “meeting”) is a native macOS menu bar app for meetings, private occurrence notes and recurring meeting context. It uses local SwiftData storage and optional on-device AI. The core supports macOS 15 or newer; AI requires macOS 26 or newer, supported Apple Intelligence hardware/language, Apple Intelligence enabled and a ready model. Full test/Release validation uses Xcode 27; Xcode 26.4.1 also passed a signed Debug build and clean GUI opening. The property-list project keeps Xcode 16.0 format compatibility. Use Xcode 26.4.1 for editing if this Xcode 27 installation displays its `project.xcproj` lock issue; see the validation report. macOS 15 runtime needs separate validation.

## Build and run

Open `Kaigi.xcodeproj`, select the **Kaigi** shared scheme and **My Mac**, then build/run. The existing project was renamed in place; it retains Debug/Release, unit/UI targets, capabilities and automatic signing.

- Installed name, executable and product: **Kaigi**.
- Registered bundle ID: **`com.volrik.kaigi`**, verified in Apple Developer and the existing macOS App Store Connect record on 28 October 2026.
- Team: **`WX557M9HD2`**; Automatic signing. Version **1.0**, build **1**, unchanged.
- App Store Connect listing: **Kaigi - Meeting Notes** (Apple ID **6828158632**); preserve this exact owner-selected name.
- Swift module: **`Meetrail`**, deliberately retained to preserve SwiftData model runtime identity. Test imports retain this name; project and test products use Kaigi.

```sh
xcodebuild -project Kaigi.xcodeproj -scheme Kaigi -configuration Debug build
xcodebuild -project Kaigi.xcodeproj -scheme Kaigi -configuration Release build
xcodebuild -project Kaigi.xcodeproj -scheme Kaigi -destination 'platform=macOS' \
  -parallel-testing-enabled NO test
python3 Tools/verify-architecture.py
python3 Tools/test-transfer-data.py
git diff --check
```

Use the existing development certificate/private key. A restricted shell may not see keychain identities: verify with authorized keychain access or an actual signed Xcode attempt before diagnosing a missing identity. Never generate/revoke certificates to work around a test limitation. No CI, Fastlane, automatic version update, archive upload or TestFlight upload is configured or performed.

Debug-only `--sample --show-agenda` uses synthetic calendars and in-memory notes without requesting calendar access. `--context-history` seeds earlier synthetic notes/context; `--mock-ai` enables explicitly synthetic AI previews. Add `-NSAppearance Aqua` or `-NSAppearance DarkAqua` for appearance review. `--onboarding --fifty-calendars`, `--empty`, `--one-meeting`, `--fifteen-meetings`, `--long-titles`, `--large-text` and `--constrained-height` exercise layout. `--test-session ID` retains only synthetic preferences across launches. Debug-only `--sample --live-system-services` keeps calendars/notes synthetic while using the real notification and login adapters; ordinary sample mode continues to use preview services. UI tests need an interactive automation session and an ABC keyboard input source for Latin text entry. Prepare the real calendar fixtures with `Tools/run-calendar-qa.sh` before the live integration test and clean them afterward with `Tools/run-calendar-qa.sh --cleanup`; only tracked attendee-free workflow events are removed.

## Use and capabilities

The single-day, content-sized 344-point agenda has a bounded scroll viewport, separate note and Join actions, destination-labeled conference links and keyboard navigation (Command-left/right, Command-T, Command-[, Command-comma). Right-click the template menu-bar symbol for Settings and Quit Kaigi. Notes belong to meeting occurrences; there is no standalone notes browser.

Editors autosave locally, support revision restoration and user-selected Markdown export, and share state with floating notes. The resizable History & Context window shows earlier occurrences, manually confirmed recurring context and explicit carryover. No task owner, deadline or completion is inferred. Notes from missing calendar events remain recoverable as occurrence cards on their original agenda day. Changed event/calendar identities are kept conservatively separate.

Clean Up and Structure use Apple Foundation Models on supported devices. Proposed changes require review and Apply; originals are retained as revisions. Unsupported languages or model/device readiness surface an honest unavailable/error state. Direct provider connections and external AI services are not implemented. Synthetic AI is a test fixture, never a live provider claim.

Only Apple / System Calendars connects today. Existing Google/Microsoft/CalDAV accounts already synchronized through macOS work via EventKit. Calendar permission is requested only by an explicit Connect action. Production adapters remain read-only. Other direct providers are labeled Coming Soon.

Optional local reminders omit private meeting titles/notes and require separate notification consent. Launch at login uses `SMAppService.mainApp` and depends on the installed app location and macOS approval. Calendar permission, notification authorization, login registration, real AI readiness and external conference entry are device/account-dependent; synthetic UI tests do not validate those services.

## Rebranding and data

**The old installed app and its store are not migrated or removed automatically.** The new bundle ID has a separate sandbox, defaults domain, permission identity and login registration. Read [the data transfer procedure](Docs/DataMigration.md) before switching. It includes a verified owner-run offline helper, intact backups, a refusal to overwrite existing files, and explicit rollback instructions. Markdown alone is not a full revision/history backup.

`MeetingSeries`, `MeetingNote`, `NoteRevision`, their stored properties, module namespace, UUIDs, system occurrence keys, `selectedCalendars` (including empty/missing selections), other preference keys, `default.store` and CloudKit `.none` are preserved. Store initialization failures never reset data. Keep real notes, account data, backup stores and sensitive screenshots outside Git.

[Brand rules](Docs/Brand/DesignSystem.md) document the purple Light/Dark palette, three control levels and four system-font roles. [Rebranding validation](Docs/RebrandingValidation.md) records actual build, test, visual and migration evidence plus untested surfaces.

## Architecture

Views → ViewModels → Domain use cases/services → repository/provider protocols → Data/Infrastructure adapters. App composition files construct concrete dependencies and coordinate windows. Feature ViewModels use Foundation/Observation with `@MainActor @Observable`; SwiftData, EventKit and Foundation Models stay in Data. Export, browser, notifications, login and permission-settings adapters live in Infrastructure. Shared DesignSystem components render values and forward actions.

Calendar providers register through `CalendarAccountCoordinator`. Future provider identities are namespaced by provider/account/calendar. Matching never uses titles alone. Selection remains keyed by stable calendar IDs, and temporarily missing calendars remain selected. All authored stack spacing/padding uses AppSpacing (0/8/16/24/32/40/48); geometry is separate. Every SwiftUI View modifier starts on its own line.

`Tools/CalendarQA.swift` is outside all app/test targets. It alone can create attendee-free synthetic fixtures, tracking IDs in a manifest outside Git and cleaning only those workflow events. The legacy `Meetrail QA` calendar, `[Meetrail QA]` prefix and `/tmp/meetrail-qa-manifest.json` remain to safely identify existing fixtures. The QA executable itself is Kaigi Calendar QA.

## Manual GitHub rename

No remote repository or local origin is changed automatically. The intended repository is [ArtemkaK1/Kaigi](https://github.com/ArtemkaK1/Kaigi). The owner can rename the existing repository in GitHub Settings → General → Repository name, preserving its visibility and rights, or run:

```sh
gh repo rename Kaigi --repo ArtemkaK1/Meetrail --yes
git remote set-url origin https://github.com/ArtemkaK1/Kaigi.git
git remote -v
```

Use the SSH equivalent `git@github.com:ArtemkaK1/Kaigi.git` if preferred. The filesystem checkout can retain its current directory name. No branch, commit or push was created.

Notification authorization was verified after the owner allowed Kaigi in macOS (`didGrant: 1`, no error). Five-minute scheduling/replacement is covered by unit tests; sample mode intentionally suppresses scheduled reminders even when its real OS preferences adapter is selected. Actual notification-banner delivery and boot-time login after installation remain manual checks. Launch-at-login registration was tested and restored to Off.

## Distribution

Use the existing App Store Connect record **Kaigi - Meeting Notes**, bundle ID `com.volrik.kaigi`. Review its metadata, screenshots, privacy/accessibility declarations, age rating, category, rights, sandbox information, and required compliance information before submission. Do not create another App ID or app record. Build/archive manually in Xcode with automatic signing; upload only after explicit owner authorization. Marketing version changes are separate, and build numbers must be checked against accepted App Store builds before an authorized upload.

Historical Xcode Cloud/GitHub publishing workflows may still exist remotely despite local removal. Review/disable them manually before any distribution; do not rerun old publishing jobs. This task does not modify those services or the separate website repository.

## License and contribution rights

Copyright © 2026 Artemiy Kirillov. Licensed under [PolyForm Noncommercial 1.0.0](LICENSE.md). Kaigi is source-available; commercial use requires separate authorization. Contributor-rights agreements must be settled before merging outside work intended for commercial redistribution; see [CONTRIBUTING.md](CONTRIBUTING.md). Preserve all copyright/license notices.

No MeetingBar code/assets or third-party package dependencies are used. Provider artwork remains separately owned: preserve the [provider notices](Kaigi/Resources/ProviderArtworkNotices.txt) and bundled Microsoft Fabric Assets license. Apple's Calendar artwork is rendered locally and is not redistributed. See [SECURITY.md](SECURITY.md) for storage and privacy limits.

Current rebranding validation: signed Debug and universal Release builds passed; 46 unit tests, one live-calendar integration test and all 16 UI tests passed. Architecture, transfer-helper tests, original-to-Kaigi synthetic store compatibility and whitespace checks passed. The installed Release app is `/Users/artemiy/Applications/Kaigi.app`. A contended UI rerun had two focus failures while a duplicate QA instance was running; a clean full UI repeat passed without changing assertions. Full evidence, the baseline legacy-preferences incident and untested surfaces are documented in [the validation report](Docs/RebrandingValidation.md).
