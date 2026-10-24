# Meetrail MVP validation — 23–24 October 2026

Implemented locally in the existing repository, without branches, commits, pushes, visibility changes, release publication, third-party dependencies, or external contributions. Product brief was accessible and read. No applicable AGENTS.md was found in the repository or its ancestor directories.

Environment: Apple Silicon MacBook Pro, macOS 26.6.2 (25G83), Xcode 27.0 (27A266a), Swift 6.4. Core deployment target: macOS 15. Test logs and result bundles are under /tmp, outside Git. No private calendar data, actual conference links, account names, private notes, or sensitive screenshots are included in this report.

## P0 — PARTIAL: foundation and architecture

Implemented domain values, injectable calendar and AI contracts, SwiftData series/occurrence/revision persistence with CloudKit disabled, macOS 15 deployment, automatic signing with the existing developer Team and bundle ID, calendar/export sandbox entitlements, privacy description, and menu-bar-only behavior.

Files: Meetrail.xcodeproj/project.pbxproj; Meetrail/MeetrailApp.swift; Meetrail/Meetrail.entitlements; Domain/Meeting.swift; Persistence/NoteRepository.swift; Services contracts; Docs/brand-spec.md.

Commands executed: `xcodebuild -version`, `swift --version`, `sw_vers`, repository/history inspection, and `xcodebuild -project Meetrail.xcodeproj -scheme Meetrail -configuration Debug -derivedDataPath /tmp/MeetrailBuild build`.

Result: automatic signing failed because no matching Mac Development certificate/private key exists for the configured Team. Tool-sandbox execution initially also prevented Swift macro plugins; authorized local Xcode execution resolved that restriction. Subsequent ad-hoc builds passed. App Sandbox was retained. Final Release entitlements contain only sandbox, calendar access, and user-selected file read/write; Release base debugger-entitlement injection is disabled.

Real checks: installed SDK/toolchain capabilities and executable app launch. Limitation: certificate installation/authorized developer signing and execution on macOS 15 are still required for release validation. Ad-hoc binaries are not distribution artifacts and may encounter repeated OS consent checks after rebuilding.

## P1 — PASS: custom menu bar UI

Implemented a 380-point single-day agenda, full weekday/date, previous/next day, Today, scrollable chronological cards, separate note and Join actions, provider/notes/context indicators, loading/permission/empty states, semantic appearance colors, keyboard commands, accessible labels/values, original code-drawn app icons, and compact floating editors.

Files: Presentation/AgendaView.swift, AgendaViewModel.swift, StatusController.swift; Assets.xcassets; Tools/GenerateIcon.swift; MeetrailUITests/MeetrailUITests.swift.

Commands: ad-hoc Debug builds and Xcode UI tests. The reusable build override was `CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO`; this does not disable App Sandbox.

Real checks: actual status-item click, day navigation, meeting selection, light/dark agenda launches, empty state, Close, reopening, Escape dismissal, and keyboard commands. Visual inspection of the actual real-calendar agenda confirmed time/title/provider cards and a separate Join action. No monthly grid or native meeting dropdown is present.

An NSPopover implementation had unreliable startup presentation during automation. The final permitted AppKit NSStatusItem/NSPanel fallback supports normal window focus. GUI tests reproduced an AppKit constraint-loop crash on detail selection; explicit panel sizing and a scrollable detail surface resolved it. All four final GUI tests pass. No custom animations require a Reduce Motion alternative; manual VoiceOver speech and comprehensive contrast/large-text review remain in the review checklist.

## P2 — PARTIAL: calendars and conferencing

Implemented EventKit access, persisted calendar selection, read-only event fetching, cancellation/declined-event exclusion, day overlap/time-zone normalization, EventKit change notifications, safe HTTPS resolution from URL/location/description, domain-boundary provider checks, multiple-link selection, and unknown-link fallback. Calendar refresh preserves existing selection when already authorized.

Files: Services/CalendarGateway.swift, EventNormalizer.swift, MeetingLinkResolver.swift; Domain/Meeting.swift; MeetrailTests/CalendarIntegrationTests.swift; Tools/CalendarQA.swift and run-calendar-qa.sh.

Commands: Debug builds, deterministic tests, real EventKit integration tests, and the separately compiled standalone calendar QA app. Production sources contain no EventKit save/remove/calendar-creation methods.

Real checks: created a dedicated Meetrail QA calendar with attendee-free one-time, finite daily/weekly recurrence, moved occurrence, overlap, no-link, all-day, and four-provider fixtures. The actual agenda displayed them. The integration test verified all four providers, recurrence, all-day/no-link cases, absence of the moved occurrence on its former day, two distinct occurrence identities on the destination day, and refetched-note association. This test passed on the real Mac, including the 00:08:27 full-suite result bundle.

The user-supplied own-account conference link was stored only in temporary QA events outside Git. Clicking Meetrail's separate Join opened the default browser and reached the correct Google Meet pre-join page. Attempted conference entry stalled at “Still trying to get in”; active conference entry is not passed. The test tab was closed. No invitations, participants, cloud transcription, or recording were added.

The later full run skipped the real-calendar test because that rebuilt test host lacked permission; the skip is explicitly not counted as a pass. Apple permission-dialog UI was inaccessible to Computer Use, and the user approved the prompted permissions manually. Actual account-wide resynchronization and provider-side cancellation/series mutation still need manual review; deterministic changed-ID, changed-series and cancellation cases are covered.

## P3 — PASS: private notes and recurring context

Implemented local SwiftData notes with stable internal UUIDs, immediate save, editing checkpoints, exact pre-AI/pre-restore revisions, revision restoration, Markdown export, saved-note recovery independent of calendar availability, explicit context confirmation, reviewed carryover, per-series context preference, and shared floating editors.

Files: Persistence/NoteRepository.swift; Presentation/NoteEditorView.swift, AgendaView.swift, StatusController.swift; Domain/Meeting.swift; unit/UI tests.

Commands: persistence/repository restart tests, full Xcode suite, actual app termination/relaunch, and actual NSSavePanel Markdown export.

Real checks: entered a synthetic note on a real recurring QA occurrence; verified the exact text after process restart; confirmed a synthetic unresolved question; opened the next occurrence with a separate empty note; saw the previous confirmed question; explicitly carried it into the new note; opened the floating editor with the saved text. Export to /tmp/Meetrail-QA-export.md succeeded with the expected Markdown. After fixture cleanup notes remain locally owned rather than being deleted with calendar events.

Matching: same calendar and external ID; recurring meetings additionally require their original occurrence slot. One-time meetings retain notes across date changes. Changed EventKit IDs can match through the external identity. Changed external IDs/calendars stay separate; no title-similarity merge occurs. Uncertain recovery is through Saved notes and explicit copy/export rather than automatic reassociation. Live moves losing all original recurrence identity remain conservatively detached.

## P4 — PARTIAL: on-device AI

Implemented injectable AIRefinementService, deterministic mocks, optional Foundation Models behind macOS 26 availability, runtime model/language checks, input-size limit, Clean Up, guided Structure, source-excerpt validation, original/suggestion preview, discard/apply, stale-preview rejection, revision preservation, and manual confirmation independent from AI application. No external LLM or cloud fallback exists.

Files: Services/AIRefinementService.swift, FoundationModelsRefinementService.swift; Presentation/NoteEditorView.swift; deterministic tests.

Commands: model availability probe using the installed framework, build/test runs, and actual editor inspection.

Actual result: `appleIntelligenceNotEnabled`; English is supported. The editor displayed the explanatory unavailable state and disabled AI actions while manual notes continued to work. Mock generation, unavailable behavior, fabricated-excerpt rejection and original-note preservation tests pass. Real generation, quality/semantic accuracy, supported-language generation, model latency and hardware performance are unverified until Apple Intelligence is enabled and its model is ready. Exact excerpts prevent invented text in Structure but cannot establish correct semantic categorization; previews still require review.

## P5 — PARTIAL: QA and publication readiness

Implemented local reminder authorization/scheduling with generic private notification contents, calendar-change refresh, scheduling-race cancellation, launch-at-login controls, accessibility values, closed floating-window release, production entitlements, original icon generation, official licensing, contribution-rights policy, privacy/security documentation, and reproducible standalone QA instructions.

Files: Services/SystemPreferencesService.swift; Presentation refinements; MeetrailTests and MeetrailUITests; README.md; LICENSE.md; .gitignore; CONTRIBUTING.md; SECURITY.md; Docs/QA.md and this report; Tools.

Executed validation:

- Final full command: `xcodebuild -project Meetrail.xcodeproj -scheme Meetrail -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/MeetrailBuild CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO test`.
- Latest full result: 37 passing executions (33 unit parameter cases and 4 GUI tests), 0 failures, 1 calendar-permission skip. Result: /tmp/MeetrailBuild/Logs/Test/Test-Meetrail-2026.10.24_00-11-28-+0200.xcresult. Xcode reports 26 test methods including parameterized methods.
- Earlier full result: 37 passing executions, 0 failures, 0 skips, including real EventKit integration and 3 GUI tests. Result: /tmp/MeetrailBuild/Logs/Test/Test-Meetrail-2026.10.24_00-08-27-+0200.xcresult. The fourth GUI test was subsequently added for empty-state/dismissal coverage.
- Final time-zone refresh correction: `-only-testing:MeetrailTests/MeetrailTests test` passed all deterministic cases. This also covers the background day/time-zone-notification regression. Crossing midnight during real debugging exposed a main-thread AppKit assertion; notification observers now explicitly dispatch to the main actor.
- Normal Debug and Release `build` commands passed. Final logs: /tmp/meetrail-final-debug.log and /tmp/meetrail-final-release.log. The unrelated Xcode AppIntents metadata warning is benign; no AppIntents dependency is used. The Retina icon-dimension warnings were corrected.
- `git diff --check` and QA shell syntax validation passed. Source/history audit found no credential/signing-material patterns in 11 historical blobs across 2 commits. All 45 current source/assets/docs paths were checked separately; the supplied private conference link is absent. Full LICENSE.md body matches the canonical downloaded license byte-for-byte after the separate required copyright notice. Copyright holder was confirmed by the user. No package dependencies are bundled; no MeetingBar code/assets were used.
- Notification authorization was approved; the actual Settings toggle became enabled and macOS accepted scheduling requests without errors. The app reminder preference was then restored to Off and pending requests were canceled. Visual banner delivery was not verified because the system notification UI is excluded from Computer Use. Login-item registration at login was not performed from the temporary ad-hoc app.
- Cleanup ran through the standalone QA app and removed only manifest-tracked, prefixed, attendee-free fixtures. Calendar.app search for `[Meetrail QA]` showed No Results. The dedicated calendar was retained; the user's original planned meeting was untouched. Synthetic local notes are retained for recovery review; Saved notes and the exact original note were verified again after cleanup. The temporary export remains outside Git.

A single final idle snapshot measured 0.0% CPU and 91,040 KiB RSS (about 89 MiB); this is not an extended performance profile. The normal debug app is left running on the recovered synthetic note. A fresh ad-hoc consent identity may require clicking Connect calendars again after rebuilding; this is distinct from the earlier successful real-calendar validation.

Remaining review: install an authorized Mac Development certificate/private key; enable/download Apple Intelligence for real AI tests; verify active conference connection; validate notification banner delivery and login-item operation from an installed signed app; exercise actual permission revocation/provider resync, full VoiceOver speech and Reduce Motion settings, macOS 15 execution, and extended CPU/memory/durability testing. Use Docs/QA.md for concrete steps. No public release readiness claim is made for these unperformed checks.
