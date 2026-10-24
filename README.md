# Meetrail

**Your meetings. Your notes. All connected.**

A privacy-first macOS menu bar app for meetings, personal notes, and recurring meeting context. Powered by on-device AI.

Meetrail is a native, source-available macOS MVP. The core runs on macOS 15 or newer; optional AI requires macOS 26 or newer, supported Apple Intelligence hardware/language, Apple Intelligence enabled, and a ready model. Xcode 27 was used for development. The minimum deployment target compiles against macOS 15 APIs; execution on macOS 15 still needs a separate machine.

## Implemented

- Custom 380-point SwiftUI day agenda in an AppKit status-item panel, chronological cards, previous/next day and Today controls. No month grid or native meeting dropdown.
- EventKit calendar permission, selection, change notifications, canceled/declined event filtering, all-day and recurring events from macOS calendar accounts.
- Separate note and Join actions, recognized Google Meet, Zoom, Teams and Webex HTTPS links, destination-labelled fallback for other HTTPS links.
- Local SwiftData occurrence notes, immediate autosave, revision restoration, Markdown export, saved-note recovery after calendar disappearance, and floating notes panels.
- Explicitly confirmed recurring context with reviewed carryover and a per-series display preference.
- On-device Clean Up and guided Structure, availability/language checks, preview before apply, original revisions, and deterministic injectable AI mocks. Structure rejects excerpts absent from the original input.
- Optional private local reminders and launch-at-login controls.

Implementation is not a claim that every device-level scenario has passed. See [validation](Docs/VALIDATION.md) for actual results and remaining review checks.

## Build and run

Open `Meetrail.xcodeproj`, select the Meetrail scheme and My Mac, and build/run. The existing automatic-signing configuration uses Team `WX557M9HD2` and Bundle ID `com.volrik.meetrail`; supply an authorized Mac Development certificate/private key for that team, or choose your own team and bundle ID for your local build.

```sh
xcodebuild -project Meetrail.xcodeproj -scheme Meetrail -configuration Debug build
xcodebuild -project Meetrail.xcodeproj -scheme Meetrail -destination 'platform=macOS' test
```

On a Mac without that development certificate, local debugging can use ad-hoc signing while retaining App Sandbox:

```sh
xcodebuild -project Meetrail.xcodeproj -scheme Meetrail -configuration Debug \
  -derivedDataPath /tmp/MeetrailBuild CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO build
open /tmp/MeetrailBuild/Build/Products/Debug/Meetrail.app
```

Ad-hoc builds are for local review; they are not signed/notarized distribution artifacts. macOS may request calendar consent again after an ad-hoc rebuild. No installer or release has been published. Click the note icon in the menu bar, connect calendars, and approve the calendar prompt. Add Google/Microsoft/CalDAV accounts through macOS Calendar/Internet Accounts. No provider OAuth is implemented in Meetrail. Debug-only `--sample --show-agenda` provides synthetic data without calendar access.

## Use

Click a meeting body to edit its occurrence note; Join opens the recognized conference HTTPS link. Multiple or unknown links show their destination in a chooser. Sample fixture links are placeholders, never genuine conferences. Command-left/right moves a day; Command-T returns to Today. Tab navigates controls; standard text editing and undo work in the editor. The pin button opens a floating editor. Revisions restores an earlier saved version while preserving the current version as another revision. Export writes a user-selected Markdown file.

Confirmed context is manually reviewed text. Use “Confirm context” to make it eligible for later occurrences, then explicitly carry it into a later note. No task owner, deadline, or completion state is inferred. Saved notes retains notes after event deletion or an uncertain calendar resync. Fully changed external/calendar identities intentionally do not auto-reattach; recover the original text from Saved notes and export/copy it into the intended meeting after review.

## Architecture and storage

`Domain` contains value models and calendar-day operations. `Services` contains injectable calendar/AI contracts, EventKit normalization, URL resolution, Foundation Models, notifications, and login-item integration. `Persistence` holds SwiftData notes, local series IDs and revisions with CloudKit disabled. `Presentation` contains the observable agenda view model, SwiftUI views, status panel, and floating panels. No third-party package dependencies are used.

Production events are always read-only. The local series and note UUIDs are independent of EventKit IDs. Matching uses calendar + external event ID, plus the original occurrence date for recurring meetings. One-time meetings retain notes when moved; recurring moves retaining their original slot can preserve notes. Changed external IDs/calendars remain conservatively separate. Calendar cancellations never delete notes.

Notes are stored in Meetrail's sandbox Application Support directory (the system SwiftData `default.store` and sidecars). Preserve the entire store together when backing up. There is no built-in cloud sync or custom encryption. Private drafts and revisions are never written into calendar events. See [SECURITY.md](SECURITY.md).

`Tools/CalendarQA.swift` is separate from every app/test target. It creates attendee-free synthetic fixtures in `Meetrail QA` and writes an identifier manifest outside the repo. Its `--cleanup` path removes only manifest-listed, prefixed, attendee-free events and retains the calendar. See [QA instructions](Docs/QA.md).

## License and contribution rights

Copyright © 2026 Artemiy Kirillov. Licensed under the official [PolyForm Noncommercial License 1.0.0](LICENSE.md). Meetrail is source-available, not OSI-approved open source. Noncommercial use, study, modification and redistribution are permitted only under the license terms. Commercial use requires separate authorization from the copyright holder. The original author may separately distribute their own original application commercially, subject to third-party and contributor rights.

Outside code is not automatically accepted. Contributor-rights agreements must be settled before merging outside work intended for commercial redistribution; see [CONTRIBUTING.md](CONTRIBUTING.md). No MeetingBar source or assets are used. Apple SDKs/frameworks are used under Apple's applicable terms. There are no bundled third-party dependencies or additional notices to preserve.

App Store subtitle candidate: *Meetings and notes, connected*. Naming/trademark clearance and App Store review remain future release tasks.
