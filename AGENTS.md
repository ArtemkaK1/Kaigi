# Meetrail project rules

Work in the current checkout/branch. Do not create branches, commits, pushes, releases or visibility changes without the owner's explicit instruction. Preserve PolyForm Noncommercial 1.0.0 and contributor-rights requirements.

## Dependency direction

Views → ViewModels → Domain use cases/services → repository/provider protocols → concrete Data/Infrastructure adapters. Construct concrete dependencies only in App/ composition files. Shared DesignSystem components render values and forward actions. No singleton service lookup in features.

- Views render state, bind user input and forward actions. Never query calendars, persist notes, open system services, run AI, or perform matching in a View.
- Feature ViewModels use `@MainActor @Observable`, Foundation/Observation and injected domain use cases/protocols. Do not import SwiftUI, AppKit, EventKit, SwiftData, FoundationModels or concrete adapter types into ViewModels.
- Domain uses Foundation and immutable Sendable value snapshots/typed IDs. It must not import UI, EventKit, SwiftData, or Foundation Models.
- Data owns EventKit, SwiftData, and AI adapter implementation. Infrastructure owns window-independent OS export, browser, notification, permission-settings and login-item adapters. App/ owns composition and window coordination.
- Provider implementations register through CalendarAccountCoordinator. Only the system provider is active today. Future provider event identities must be namespaced by provider/account/calendar; never deduplicate or associate notes using titles alone. No direct external OAuth/REST/CalDAV integrations in this iteration.
- Preserve `MeetingSeries`, `MeetingNote`, `NoteRevision` names, stored properties, module identity, the default store location, CloudKit `.none`, and existing system occurrence keys. An incompatible schema change needs an explicit migration plan and compatibility tests; never delete/reset a store on failure.
- Keep calendar selection keyed by stable calendar IDs, including temporarily missing IDs. An intentionally empty selection is not an uninitialized selection. Retain existing `selectedCalendars` preferences.
- Request system calendar permission only on an explicit connection action. Production calendar adapters stay read-only. Attendee-free QA writes belong solely to Tools/CalendarQA.swift outside app targets; track and clean only workflow fixtures.

## Design and validation

Every SwiftUI View modifier must start on its own line, including the first modifier. Never chain multiple View modifiers on the same line.

All authored stack spacing/padding uses AppSpacing (0/8/16/24/32/40/48). Feature Views use `.appText` and AppColors. Four scaled native font roles: 11/13/16/20; only regular/medium/semibold. Intrinsic controls, borders and sizing metrics are separate documented geometry tokens. Keep the main agenda single-day, compact, and keyboard/VoiceOver operable. Size the agenda panel from rendered content with a bounded scroll viewport; do not restore estimated row-count heights or hidden titlebar space. Notes belong to meeting occurrences and their history; do not reintroduce a standalone notes browser.

Use normal automatic signing when the existing development identity is available. A restricted tool shell may not see keychain identities; verify using an authorized keychain read or an actual Xcode signing attempt before diagnosing a missing certificate. Never generate or revoke identities as a testing shortcut.

Run `python3 Tools/verify-architecture.py`, appropriate unit/UI tests, Debug and Release builds, and `git diff --check`. Do not remove failures, convert defects into skips, or present mocked providers/AI as live implementations. Document permission, signing, OS and external-service limits honestly in README.md. Keep real notes, account data, conference URLs, test store backups and sensitive screenshots outside Git. Synthetic before/after screenshots are permitted.
