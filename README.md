# Meetrail

**Your meetings. Your notes. All connected.**

A privacy-first macOS menu bar app for meetings, personal notes, and recurring meeting context. Powered by on-device AI.

Meetrail is a native, source-available macOS MVP. The core runs on macOS 15 or newer; optional AI requires macOS 26 or newer, supported Apple Intelligence hardware/language, Apple Intelligence enabled, and a ready model. Xcode 27 was used for development. The minimum deployment target compiles against macOS 15 APIs; execution on macOS 15 still needs a separate machine.

## Implemented

- Custom content-sized 344-point SwiftUI day agenda in a native AppKit status-item popover, chronological cards, previous/next day and Today controls. No month grid or native meeting dropdown.
- Dedicated first-run onboarding with skip/resume, honest provider connection states, and searchable account-grouped calendar selection, including per-account selection controls.
- EventKit calendar permission on explicit connection, stable selection across renames/revocation, change notifications, canceled/declined event filtering, all-day and recurring events from macOS calendar accounts.
- Separate note and Join actions, recognized Google Meet, Zoom, Teams and Webex HTTPS links, destination-labelled fallback for other HTTPS links.
- Local SwiftData occurrence notes, immediate autosave, revision restoration, Markdown export, meeting-based recovery after calendar disappearance, and floating notes panels.
- Explicitly confirmed recurring context with reviewed carryover and a per-series display preference.
- On-device Clean Up and guided Structure, availability/language checks, preview before apply, original revisions, and deterministic injectable AI mocks. Structure rejects excerpts absent from the original input.
- Optional private local reminders five minutes before meetings and launch-at-login controls.

The P11 local signed suite passed 64 executions with no failures or skips, including real EventKit and eleven GUI tests. Real on-device Clean Up/Structure and own-account Google Meet entry were verified on the development Mac. Implementation is not a claim that every device-level scenario has passed.

## Build and run

Build and publish manually in Xcode. The app identity is `com.volrik.meetrail.app`, team `WX557M9HD2`, version `1.0`, build `1`. No CI build, automatic upload or build-number update is configured.

Open `Meetrail.xcodeproj`, select the Meetrail scheme and My Mac, and build/run. The automatic-signing configuration uses Team `WX557M9HD2` and Bundle ID `com.volrik.meetrail.app`; supply an authorized development certificate/private key for that team, or choose your own team and bundle ID for your local build.

```sh
xcodebuild -project Meetrail.xcodeproj -scheme Meetrail -configuration Debug build
xcodebuild -project Meetrail.xcodeproj -scheme Meetrail -destination 'platform=macOS' \
  -parallel-testing-enabled NO test
python3 Tools/verify-architecture.py
```

On a Mac without that development certificate, local debugging can use ad-hoc signing while retaining App Sandbox:

```sh
xcodebuild -project Meetrail.xcodeproj -scheme Meetrail -configuration Debug \
  -derivedDataPath /tmp/MeetrailBuild CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO build
open /tmp/MeetrailBuild/Build/Products/Debug/Meetrail.app
```

Ad-hoc builds are for local review; they are not signed/notarized distribution artifacts. macOS may request calendar consent again after an ad-hoc rebuild. No installer or release has been published. First run opens a dedicated Welcome window. Choose Apple / System Calendars to request macOS calendar access, then select visible calendars grouped by account. Skip for now preserves your progress; Settings → Accounts & Calendars remains available. Existing notes, calendar selections, and preferences are retained, and returning users are not forced through setup.

Only Apple / System Calendars connects today. Existing Google/Microsoft/CalDAV calendars already synchronized through macOS remain usable via EventKit. Direct Google, Microsoft, Yandex, Zoho, and CalDAV connections are Coming Soon and will be implemented separately; there are no OAuth clients, tokens, or fake authentication states.

Debug-only `--sample --show-agenda` uses synthetic data without calendar access. Add `--onboarding --fifty-calendars` to review first run and 50 calendars across five accounts. `--empty`, `--one-meeting`, `--fifteen-meetings`, and `--long-titles` exercise layout. Optional `--test-session ID` persists synthetic onboarding/selection preferences across relaunch; sample notes are in memory. For XCTest Latin typing, select the ABC keyboard input source; restore your preferred source afterward.

Folder cleanup validation (25 October 2026): the architecture check, signed Debug and Release builds, 43 deterministic unit tests, one synthetic UI smoke test, and `git diff --check` passed. Signing required keychain access outside the restricted shell. Real-calendar integration, on-device AI, external meeting entry, and distribution upload were not rerun for this documentation-only change.

## Manual distribution

Use the **Meetrail** scheme in Xcode 27 with Automatic signing and the team above. Confirm that the Apple Developer App ID and macOS App Store Connect record both use **`com.volrik.meetrail.app`**. For TestFlight, choose Product → Archive, then select the archive in Organizer and use Distribute App → App Store Connect to upload. Review the version and build number before uploading; wait for App Store Connect processing before assigning testers. See [Apple's distribution guide](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases).

Manage the app target's **Build** value manually in both Debug and Release configurations: start at `1` for an unused app record, then use `2`, `3`, and so on for subsequent uploads. If App Store Connect has already accepted builds for this bundle ID, use a number higher than the latest accepted build. Marketing version changes are separate.

The new bundle ID uses a separate sandbox container, preferences and permission identity. Old notes remain in the old app's container. Back up/export important notes outside Git and retain the old installation until any required data transfer is resolved. No data migration is implemented.

The repository's GitHub Actions publishing workflow, Fastlane setup and Xcode Cloud hooks/test plan/scheme have been removed. Disable or delete any existing **Publish to TestFlight** workflow in App Store Connect → this app → Xcode Cloud, and disable the old GitHub Actions workflow while its removal is pending. Do not rerun historical publishing jobs. Remove the obsolete GitHub `testflight` Environment and its signing secrets when no other automation needs them; keep Apple certificates used for local signing. Removing repository files does not disable workflows stored in Apple's service.

Manual validation continues to use the original **Meetrail** scheme and all existing tests. Real-calendar tests require an account and permission; real AI tests require a ready Apple Intelligence model; UI tests require a working interactive automation session. No distribution upload was performed for this cleanup.

CI-removal validation (28 October 2026): signed Debug and Release builds, 43 unit tests (including the local real-model tests), architecture checks, project parsing and `git diff --check` passed. Real-calendar integration and UI automation were not rerun. Both builds retained the new bundle ID, version `1.0`, build `1` and menu-bar configuration.

## Use

Click a meeting body to edit its occurrence note; Join opens the recognized conference HTTPS link. Multiple or unknown links show their destination in a chooser. Sample fixture links are placeholders, never genuine conferences. Command-left/right moves a day; Command-T returns to Today. Tab navigates controls; standard text editing and undo work in the editor. Right-click the menu bar icon for Settings and Quit; left-click opens or dismisses the agenda. Command-comma opens Settings. The compact chevron returns to the agenda (Command-[). The pin button opens a floating editor. Revisions restores an earlier saved version while preserving the current version as another revision. Export writes a user-selected Markdown file.

Confirmed context is manually reviewed text. Use “Confirm context” to make it eligible for later occurrences, then explicitly carry it into a later note. No task owner, deadline, or completion state is inferred. Notes from disappeared events appear as Calendar history meeting cards on their original agenda day. Meeting history opens other saved occurrences of the same series. Fully changed external/calendar identities intentionally do not auto-reattach; export/copy the original text into the intended meeting only after review. There is no standalone notes browser.

Settings includes an On-device AI switch. Clean Up and Structure propose changes to the current note in a Review changes state; Apply saves a revision, while Cancel leaves the original intact. AI availability and processing remain entirely local.

## Architecture and storage

The dependency direction is Views → ViewModels → domain use cases → repository/provider protocols → Data/Infrastructure adapters. `App/DependencyContainer` and the App composition files construct dependencies and coordinate native windows. Features consistently use `@MainActor @Observable` ViewModels with injected protocols/use cases; Views only render, bind, and forward actions. SwiftData objects, EventKit stores, and AI sessions do not enter features.

- `DesignSystem/Tokens` centralizes AppSpacing (0/8/16/24/32/40/48), semantic light/dark AppColors, scaled native system text roles (caption 11, body 13, section 16, title 20) and regular/medium/semibold weights. Geometry metrics are separate from spacing.
- `Features` contains Agenda, MeetingDetail, Settings, CalendarAccounts, and Onboarding View/ViewModel pairs.
- `Domain` contains Sendable snapshots, typed IDs, provider/account/calendar/connection models, normalization, selection, visibility, note/context, join and conservative association use cases.
- `Data` owns the EventKit provider, unchanged SwiftData schema, preferences adapter, and Foundation Models adapter. `Infrastructure` owns notifications/login, validated URL opening, system-settings navigation and user-selected Markdown export.

Register future adapters through `CalendarAccountCoordinator` in the composition root. Provider-neutral calendar descriptors drive the same selection and onboarding screens; occurrence identities are namespaced outside the legacy system provider. No title-only cross-provider deduplication is performed. The lightweight architecture/design check enforces imports, feature adapter boundaries and token use; see [AGENTS.md](AGENTS.md). No third-party package dependencies are used.

The EventKit adapter owns its store and event objects on a private serial actor and exposes cached, immutable catalog snapshots. `CalendarProvider.prepare()` completes catalog preparation before initial visibility is persisted; providers with an immediately available catalog use the default implementation. SwiftData contexts remain on their existing main actor. Opening today's popover reuses an in-flight or current agenda; EventKit, day and time-zone changes still refresh it.

Production events are always read-only. The local series and note UUIDs are independent of EventKit IDs. Matching uses calendar + external event ID, plus the original occurrence date for recurring meetings. One-time meetings retain notes when moved; recurring moves retaining their original slot can preserve notes. Changed external IDs/calendars remain conservatively separate. Calendar cancellations never delete notes.

Notes are stored in Meetrail's sandbox Application Support directory (the system SwiftData `default.store` and sidecars). Preserve the entire store together when backing up. There is no built-in cloud sync or custom encryption. Private drafts and revisions are never written into calendar events. See [SECURITY.md](SECURITY.md).

`Tools/CalendarQA.swift` is separate from every app/test target. It creates attendee-free synthetic fixtures in `Meetrail QA` and writes an identifier manifest outside the repo. Its `--cleanup` path removes only manifest-listed, prefixed, attendee-free events and retains the calendar.

## License and contribution rights

Copyright © 2026 Artemiy Kirillov. Licensed under the official [PolyForm Noncommercial License 1.0.0](LICENSE.md). Meetrail is source-available, not OSI-approved open source. Noncommercial use, study, modification and redistribution are permitted only under the license terms. Commercial use requires separate authorization from the copyright holder. The original author may separately distribute their own original application commercially, subject to third-party and contributor rights.

Outside code is not automatically accepted. Contributor-rights agreements must be settled before merging outside work intended for commercial redistribution; see [CONTRIBUTING.md](CONTRIBUTING.md). No MeetingBar source or assets are used. Apple SDKs/frameworks are used under Apple's applicable terms. There are no third-party package dependencies. Provider artwork remains separately owned and is not covered by Meetrail's license; preserve the [artwork notices and source references](Meetrail/Resources/ProviderArtworkNotices.txt) and bundled Microsoft Fabric Assets license. Apple's installed Calendar icon is rendered locally and is not redistributed.

App Store subtitle candidate: *Meetings and notes, connected*. Naming/trademark clearance and App Store review remain future release tasks.
