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

# Stabilization P6–P10 — 24 October 2026

This section supersedes the earlier P0–P5 environment limitations where newer evidence is recorded. It continues the existing app in the current checkout. No branch, commit, push, repository publication, license change, direct external provider API, backend or cloud AI was introduced.

## P6 — PASS: investigate and resolve prior incomplete work

| Previous incomplete result | Root-cause classification | Investigation and resolution |
| --- | --- | --- |
| P0 signing certificate | Previous local environment / restricted test visibility | A restricted shell reported zero identities, which was an incorrect basis for declaring the certificate absent. The authorized keychain check found the existing Apple Development and distribution identities. Normal Xcode Debug and Release builds sign successfully using the existing Apple Development identity and Team WX557M9HD2. No identity was generated or revoked. |
| P2 URL parsing / provider recognition | Validation coverage | Existing resolver tests and real QA EventKit events verify Google Meet, Zoom, Teams and Webex, multiple fields, HTTPS validation, spoofed hosts and unsafe schemes. The production gateway remains read-only. |
| P2 actual live connection | Manual verification / browser permission | Meetrail's separate Join action opened the supplied own-account Google Meet link. Safari initially waited on a media permission prompt inaccessible to automation. The user selected Don't Allow. The page then showed camera/microphone off; Join now reached “You have joined the call” and “You are the first one here.” The QA tab was closed. No invitations, recording, transcription or Gemini notes were started. Other providers' real native-client/call entry was not tested using placeholder links. |
| P4 Apple Intelligence disabled | Local environment changed | The runtime model now reports available, with English supported. Real Clean Up and Structure inference passed on this Mac. The structured synthetic example preserved no decisions/actions and extracted a question. Unsupported-language rejection, unavailable fallback, deterministic mocks, stale previews and revisions are tested separately. Mock output is not counted as real inference. |
| P5 calendar-permission skip | Isolated/ad-hoc test-host permission | Baseline and intermediate isolated hosts lacked consent; those skips remain recorded as skips. The separate real-calendar run passed after safe fixtures were installed. The final normally signed full run completed the same unchanged calendar integration test without a skip. |
| P5 unfinished manual QA | Manual verification not performed / unavailable environment | Long notes, autosave, restart, undo/redo, context carryover, floating notes and Markdown export were rechecked. Full VoiceOver spoken output, notification banner delivery, actual login/restart, permission revocation/reapproval, provider-wide resync, macOS 15 execution and extended profiling remain explicit manual checks. |
| Baseline GUI regressions | Incorrect test setup / local input and activation | Reproduced 33 unit executions passing, one real-calendar skip and four GUI failures. Russian input caused XCTest Latin text synthesis to time out; ABC allowed typing. Native activation/reopen races were addressed in the harness by explicit activation; panel queries use dialog semantics. Existing assertions were retained. A Safari permission interaction interrupted one intermediate signed appearance test; the controlled final suite passed all GUI tests, including the new native Settings regression. |
| Native Settings command | Application defect / missing regression test | Command-comma could construct an empty Settings scene before dependency initialization. Composition now resolves injected ViewModels before scene construction; windows still open after launch. A ninth native GUI test verifies Settings and account-management routing. |
| Note-save failure handling | Application defect | Failed saves could leave mutated persistence objects/checkpoint state. Writes now roll back, checkpoints advance only after success, editor drafts remain available for retry, quit retries drafts and offers to stay open on failure, and export includes the current draft even if saving failed. |

Files: `Data/Notes/NoteRepository.swift`, `Domain/UseCases/NoteUseCases.swift`, `Features/MeetingDetail/MeetingDetailViewModel.swift`, App window/termination handling, existing/new tests and the validation documentation. Existing signing settings, bundle ID, sandbox and privacy descriptions were retained.

Commands/results: baseline ad-hoc `xcodebuild ... test` (/tmp/meetrail-p6-baseline.log) reproduced the failure; focused unit runs passed; normal `xcodebuild ... build` now passes in Debug and Release. `security find-identity -v -p codesigning` must run with keychain access; `codesign --verify --strict` passes. Release entitlements are only App Sandbox, calendar access, and user-selected file read/write; Debug additionally permits debugger attachment. Required user action for signing: none on this Mac. Distribution/notarization is not part of this task.

## P7 — PARTIAL: compact agenda and consistent design system

The single-day agenda is 344 points wide. Synthetic before/after captures measure 380 × 550 versus 344 × 392 points for the same three-meeting surface, about 35% less area. Height adapts to content and screen bounds; many meetings scroll. Date navigation, Today, separate note/Join actions, loading, permission, empty, saved-note and settings access remain available.

| Audit | Final implementation |
| --- | --- |
| Padding and stack spacing | One AppSpacing definition: 0, 8, 16, 24, 32, 40, 48. Source check passes. |
| Typography | Four native system roles: caption 11, body 13, section 16, title 20. Regular/medium/semibold only. ScaledMetric plus centralized Dynamic Type scale floor handles macOS leaving explicit accessibility sizes at base metrics. Feature Views have no independent font definitions. |
| Colors | AppColors centralizes semantic text, backgrounds, surfaces, borders, accent, warning/error, selection and disabled states. Calendar RGB values are data converted through a shared helper. Native light/dark colors; no per-feature hardcoded colors. |
| Geometry exceptions | Panel/window/editor dimensions, minimum native Mac icon hit targets, time column, corners and review viewport are AppLayout metrics, not layout-padding exceptions. Native control spacing/borders remain intrinsic. |
| Accessibility | Named native buttons/checkboxes, independent Join, state values beyond color, headers, readable Coming Soon text, separate provider accessibility groups, scrolling and standard editable text. No custom motion is authored. |

Files: `DesignSystem/Tokens/AppTokens.swift`, `DesignSystem/Components/JoinControl.swift`, all six feature Views and agenda sizing in App/. [Before](UI-before.png) and [after](UI-after.png) images contain synthetic data only. The real GUI tests cover 0/1/15 meetings, long titles, light/dark, keyboard commands, dismissal, and scaled text in a constrained panel. The scaling test compares actual card heights to ensure the font really grows. A screenshot review found and corrected centered account checkbox content. Long-note editing, undo and redo were checked manually. Full VoiceOver speech and other physical displays remain unverified; see the [accessibility audit](../skills/swiftui-accessibility-auditor/checklist.md).

## P8 — PASS: strict MVVM and durable provider boundaries

Files were reorganized into App/, DesignSystem/, Features/{Agenda,MeetingDetail,Notes,Settings,CalendarAccounts,Onboarding}, Domain/{Models,Protocols,UseCases}, Data/{Calendar/EventKit,Notes,AI,Preferences}, and Infrastructure/{Export,Notifications}. Existing URL parsing, recurrence normalization and SwiftData code were retained and adapted behind contracts, not replaced with a separate application.

| Dependency rule | Evidence |
| --- | --- |
| Views → ViewModels | Six feature View/ViewModel pairs; Views render, bind, format presentation and forward actions. No calendar queries, persistence, AI sessions or system calls in Views. |
| ViewModels → domain/use cases/protocols | Consistent MainActor Observable approach. Feature ViewModel imports are Foundation and Observation only. Separate agenda/detail/library/settings/accounts/onboarding responsibilities. |
| Domain independent from frameworks | Domain imports Foundation only, with Sendable snapshots and typed CalendarID/AccountID/NoteID. No SwiftUI/AppKit/EventKit/SwiftData/FoundationModels dependencies. |
| Protocols → adapters | CalendarProvider, NotesStore, preference, AI, link-opening, permission-settings and application-action contracts isolate EventKit, SwiftData and OS services. |
| Composition root | Concrete dependencies are constructed in App/DependencyContainer and App composition files. Native windows are coordinated in App/; features do not resolve global services. Services are resolved before Settings scene construction; native windows are created after application launch. |
| Future providers | CalendarProviderKind, CalendarAccount, CalendarDescriptor, CalendarEvent (the existing Meeting occurrence value), AccountConnectionState and CalendarAccountCoordinator are provider neutral. The root accepts a registry of adapters. Test-only alternate-provider fixtures prove the same visibility, selection and note use cases work with two registered kinds. No production OAuth/client stubs exist. |
| Conservative identity | Legacy system keys are byte-for-byte unchanged. Future provider/account/calendar keys are length-prefixed to avoid delimiter collisions. Exact identities deduplicate; ambiguous payloads are rejected. Title-only cross-provider merging is prohibited. |
| Preservation | Same SwiftData model names/properties/module/store location, CloudKit disabled, same selectedCalendars key. A transactional pre-refactor backup copy opened under the new code and every persisted row remained unchanged, including IDs, text, context, revisions and series. The live app also recovered its exact synthetic note after normal quit/relaunch. |

`AGENTS.md` records these mandatory rules. `python3 Tools/verify-architecture.py` passes framework/import boundaries, known adapter leaks, feature font/color usage and padding/spacing checks. This lightweight source guard supplements code review; it is not a formal proof of every possible dependency. New tests cover save failures/retry/export, shared floating state, stale AI preview safety, old-data/selection migration, provider namespacing/collisions and registration. No database reset, format replacement or destructive migration was performed.

## P9 — PASS: first-run onboarding and account management

Files: `Features/Onboarding/*`, `Features/CalendarAccounts/*`, `Features/Settings/*`, `Data/Preferences/AppPreferencesStore.swift`, domain calendar/coordinator/visibility models and use cases, App composition/window routing, `MeetrailTests/StabilizationTests.swift`, `TestComposition.swift`, expanded `MeetrailUITests.swift`.

Welcome → Connect Calendars → Select Visible Calendars → You're Ready runs in a dedicated 680 × 580 content window with native resize/close behavior. Setup can be skipped and reopened; stage/disposition persist in a new calendarOnboarding.v1 preference. Existing selections or notes classify returning users without forcing onboarding or resetting their data. Completion/skip returns to the agenda.

Only an explicit Apple/System connection requests calendar permission. The other five cards honestly say Coming Soon and have no authentication button. System calendars already synchronized through macOS remain available. Settings → Accounts & Calendars presents the same connections and selection interface; Review onboarding starts the welcome flow without resetting selections.

Selection groups actual EventKit calendars by stable account/source IDs, shows source names, calendar names and colors, uses collapsible groups and native checkboxes, search, per-account Select/Deselect All, a total selected count and retained unavailable IDs. Calendar rename preserves selection; permission revocation does not erase IDs; intentionally empty selection stays empty. New calendars are not silently substituted for missing ones.

Results: deterministic 50-calendar/five-account tests passed (one scenario completed in 0.013 seconds; not an extended performance profile). Native UI checks verified connection, search, checkbox selection, all/none group behavior, collapse, completion and skip/relaunch persistence. Tests with injected denied access verify a settings action rather than fake connection. Real EventKit accounts/calendars also render through this model. Synthetic provider fixtures are not represented as real Google or Microsoft connections.

## P10 — PARTIAL: regression and manual product review

Implementation and automated regression are complete. Remaining manual/environment-specific checks below prevent claiming every release/device scenario has passed.

Final command family (normal automatic signing; no ad-hoc override):

```sh
xcodebuild -project Meetrail.xcodeproj -scheme Meetrail -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/MeetrailSigningCheck build
xcodebuild -project Meetrail.xcodeproj -scheme Meetrail -configuration Release \
  -destination 'platform=macOS' -derivedDataPath /tmp/MeetrailSigningRelease build
xcodebuild -project Meetrail.xcodeproj -scheme Meetrail -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/MeetrailSigningCheck \
  -parallel-testing-enabled NO test
python3 Tools/verify-architecture.py
git diff --check
```

Final results: **58 passing executions, 0 failures, 0 skips** (48 deterministic/parameterized unit executions, one real EventKit integration and nine GUI tests). Xcode summarizes these as 46 test methods. Final bundle: `/tmp/MeetrailSigningCheck/Logs/Test/Test-Meetrail-2026.10.24_12-04-03-+0200.xcresult`; log: `/tmp/meetrail-p10-complete.log`. Both real AI probes passed. Normal Debug and Release `build` actions passed for the final source; logs: `/tmp/meetrail-p10-complete-debug.log` and `/tmp/meetrail-p10-complete-release.log`. Only the unrelated AppIntents metadata extraction warning remains. Architecture checks and `git diff --check` pass.

Cleanup completed through the standalone QA app and removed the local manifest after its tracked fixture deletions. Its native result confirmed that only workflow fixtures were removed and the calendar retained. The signed Release agenda then showed no remaining meetings for the selected day, and Saved notes still recovered the exact new long QA draft as well as the original pre-refactor notes. No unrelated calendar event was modified. The QA browser tab and helper apps were closed. Russian keyboard input was restored after ABC-based UI tests. The normally signed Release app is left running with retained synthetic notes available at `/tmp/MeetrailSigningRelease/Build/Products/Release/Meetrail.app`; it has not been installed as a login item or published.

Additional synthetic captures: [provider cards](UI-onboarding.png) and [50 calendars](UI-calendars-50.png). Actual enlarged text was visually inspected and the editor was scrolled into view, edited and saved in the constrained viewport. These captures contain synthetic data only.

Manual actual-Mac evidence: real QA calendar agenda; day navigation and separate note/Join controls; owned live Google Meet call with media off; long notes and immediate save; standard undo/redo; exact note after restart; next recurring occurrence with its own empty note and previous confirmed question; reviewed carryover; shared floating editor; native Markdown export verified against expected synthetic contents; real Clean Up preview and actual structured inference; actual first-run and 50-calendar UI. No private screenshots or actual meeting links were added to Git.

A single final signed Release idle snapshot measured 0.0% CPU and 108,432 KiB RSS (about 106 MiB); this is not an extended performance profile. The native Command-comma Settings window was rechecked in the final Release build and rendered its account-management and preference controls correctly. Production Settings showed reminders and login both Off, preserving the prior preferences; Accounts & Calendars opened its dedicated window with actual system connection state. No login item was registered.

Repository readiness: PolyForm Noncommercial 1.0.0 LICENSE.md is byte-identical to the existing licensed version. No bundled dependencies or new license obligations. Working source/history scanning found no credential/private-key patterns and no non-placeholder Google Meet links in repository text. The scan is a readiness check, not a guarantee against every secret format. No fixture manifest, database backup, live link or private calendar content was added. The QA harness remains outside production targets and all production EventKit paths remain read-only.

Outstanding user/manual review actions:

- Enable VoiceOver and verify spoken reading/focus through agenda, separate Join, onboarding provider groups, calendars and editor. Source semantics, AX trees and keyboard automation pass; spoken output/Voice Control was not completed by the available automation.
- Verify visible local-notification banner delivery and denial behavior in macOS settings. Prior authorization/scheduling success is recorded above; a banner is not claimed as observed.
- Verify launch-at-login by enabling it from an installed signed copy and performing an actual logout/login. Do not infer it from a setting's presence.
- Revoke/reapprove calendar permission and perform provider-wide resynchronization in disposable data. Deterministic denial/reconnection/changed-ID tests passed; actual account-wide revocation/resync was not performed.
- Execute on a real macOS 15 Mac, other physical display sizes, and run extended CPU/memory/durability measurements. This Mac runs 26.6.2; deployment compatibility was compiled, not runtime-tested on 15.

| Phase | Status | Product-review outcome |
| --- | --- | --- |
| P6 | PASS | Signing, live Google Meet and real AI verified; baseline defects and test/environment causes resolved/classified. Remaining manual checks explicitly retained. |
| P7 | PARTIAL | Compact agenda/design implementation and automated layout coverage pass; full VoiceOver speech and additional physical displays remain unverified. |
| P8 | PASS | Consistent MVVM, provider-neutral protocols/use cases, unchanged data schema, architecture guard and compatibility checks. |
| P9 | PASS | Dedicated persistent onboarding and grouped/searchable calendar management, 50-calendar coverage; system provider only. |
| P10 | PARTIAL | Signed builds and automated regression pass; specific device/manual checks remain above. |

Ready for manual product review and for a separately scoped direct-provider implementation. Register each future adapter through the composition root, preserving stable provider/account/calendar/occurrence identity and adding its authentication/sync/permission tests. No UI or note-database rewrite is required. Direct Google, Microsoft, Yandex, Zoho and CalDAV integrations remain unimplemented and explicitly deferred.

## P11 — Focused UI/UX cleanup (24 October 2026)

This section supersedes the historical Saved Notes, embedded Settings and Review onboarding navigation described above. No branch, commit, push, publication, calendar-provider integration, note schema migration or database reset was performed.

### Changes and root causes

- The extra bottom region came from a hidden titled/full-size-content window combined with a root View fixed to estimated heights. The agenda now uses a borderless AppKit panel, rendered-content measurement and bounded scroll viewports. Geometry stays in Views/App window coordination rather than the AgendaViewModel. No negative padding or guessed row-count height remains. A single synthetic long-title card is tested for both compact total height and the absence of a redundant bottom region.
- The agenda's duplicated app heading, close control, Settings/library controls and privacy/Quit footer were removed. Left-click still toggles the agenda; right-click exposes Settings… and Quit Meetrail. Settings invokes the existing native SwiftUI Settings command, preserving one Settings scene and Command-comma. Notes use one named chevron (Command-[), history, export and pin controls.
- Meeting cards have distinct semantic surfaces and hairline boundaries, an independent high-contrast Join action and clearer time/title hierarchy. Empty states are centered within a compact region. Existing 8-point spacing, four scaled system-font roles, three weights and semantic colors are retained. A single shared button style refines existing native Buttons; decorative borders ignore hit testing.
- Saved Notes View/ViewModel and all associated navigation, callbacks and layout metrics were removed. Recovery is attached to the affected meeting's original agenda day, labelled Calendar history. Other saved occurrences of the same internal series are available from Meeting history, opening their existing editor. Live events in hidden calendars are excluded from recovery cards. No title-based reassociation was added.
- Notes have a bounded, visibly outlined editor and empty placeholder. Previous context is shown directly; Context for next time has explicit Edit/Confirm controls. Revision restoration, autosave, Markdown export and shared floating editors are preserved. Initial floating-window content height is 440 points.
- Settings has a persistent On-device AI switch, defaulting to the previously enabled behavior when the new preference is absent. Clean Up/Structure target the current note and show Review changes with Apply/Cancel. Original text stays unchanged until Apply, with stale-preview protection and revision recovery. Disabling AI cancels processing/discards the suggestion, retaining the original. Foundation Models implementation is unchanged.
- Reminders now schedule five minutes before meetings. The existing enabled/disabled preference key remains intact. Existing generation/cancellation protection and pending-request replacement are retained; a small notification-client injection permits deterministic trigger/replacement tests without changing OS settings.
- Connections / Visible calendars no longer displays Section. Provider titles wrap within consistently aligned bordered cards, and collapsed calendar accounts use less padding. Five future providers remain Coming Soon. Calendar management content is 560 × 440 points; onboarding uses 560 × 320 for Welcome, 560 × 440 for connection/selection, and 560 × 256 for Ready. Stage-based sizing belongs to the App window coordinator; permission timing and persisted onboarding state are unchanged.

During validation, an initial decorative-border overlay prevented mouse focus in TextEditor; making decorative borders ignore hit testing resolved typing. A temporary nonactivating-panel flag caused activation instability and was removed. The final borderless panel passes typing, empty-day activation/dismissal, relaunch and right-click tests. The new recovery test also caught a stale supplied snapshot; opening recovery now fetches the latest stored record. No unrelated test was removed or converted to a skip. The former Saved Notes GUI test now checks meeting-local history, keyboard navigation and reopening the saved occurrence.

### Synthetic screenshots

Screenshots contain synthetic data only. Retina captures are twice the point dimensions. The same three-meeting agenda shrank from 344 × 392 to 344 × 273 points; the empty notes view shrank from 344 × 592 to 344 × 421 points. Settings moved from the embedded panel to the existing native scene.

| Screen | Before | After |
| --- | --- | --- |
| Agenda | [Before](P11-before-agenda.jpg) | [After](P11-after-agenda.jpg) |
| Notes | [Before](P11-before-notes.jpg) | [After](P11-after-notes.jpg) |
| Settings | [Before](P11-before-settings.jpg) | [After](P11-after-settings.jpg) |
| Connections | [Before](P11-before-connections.jpg) | [After](P11-after-connections.jpg) |
| Welcome | [Before](P11-before-onboarding.jpg) | [After](P11-after-onboarding.jpg) |

Additional captures: [AI review with deterministic mock](P11-after-ai-review.jpg), [50 calendars in five account groups](P11-after-calendars-50.jpg), [compact Ready step](P11-after-ready.jpg). The AI screenshot demonstrates the review interaction, not real inference; real inference is exercised separately by the existing tests.

### Actual MacBook checks

The signed Release app read the real dedicated QA calendar and showed all-day, overlapping, recurring, no-link and supported-provider events. An existing long P10 note and its confirmed context opened from a Calendar history card. Meeting history opened its saved next occurrence in a floating editor with previous confirmed context and Carry into notes visible.

A new attendee-free workflow event received the synthetic text `P11 synthetic autosave and relaunch check.` and an unresolved question. Actual mouse focus/paste saved it immediately. Real Foundation Models returned a proposed result in Review changes; Cancel retained the exact original. This confirms real inference and the review interaction, not guaranteed semantic accuracy. After normal quit/relaunch, the exact note and its agenda badge persisted. Command-[ returned to the agenda. The compact export action opened the native Save panel and produced Markdown in `/tmp/Meetrail-P11-20261024-review.md`; its synthetic contents were checked exactly and remain outside Git.

Join opened the workflow's placeholder in Safari, which displayed the expected invalid-code page. This verifies validated URL/browser handoff only; no new live conference connection is claimed in P11. The QA tab was closed. Cleanup removed only manifest-listed fixtures, retained the dedicated calendar, and removed the local manifest. The running app reacted to EventKit changes and showed the new note as a Calendar history meeting on its original day. Reopening it preserved the exact text. A read-only SQLite comparison against `/tmp/meetrail-p11/preserved-store.sqlite` confirmed all four pre-existing note records (IDs, series IDs, occurrence keys, title, date, text, context and updated timestamp) remained identical; the only additional record was the new synthetic P11 note.

Production Settings retained reminders Off and login Off; the new AI preference defaulted to On. No login item was registered and production notification preferences were not toggled. Five-minute timing, pending-request replacement, imminent/all-day filtering and cancellation were verified through the injected notification client. A visible OS notification banner is not claimed.

The old appearance launch argument was initially ineffective. P11 corrects the debug-only synthetic appearance fixture and strengthens the existing light/dark GUI test with actual screenshot color assertions. Release continues following system appearance. Full spoken VoiceOver output, banner delivery, other physical displays and macOS 15 execution still require manual review; source semantics, actual AX trees, keyboard shortcuts, enlarged-text scrolling and automated interactions are covered. No custom animation was introduced.

### Final build/test results

**P11 implementation: PASS.** On this MacBook Pro (macOS 26.6.2, existing automatic development signing), the final complete suite passed **64 executions, 0 failures, 0 skips**: 52 deterministic/parameterized unit executions, one real EventKit integration and 11 GUI tests (52 methods). Existing real Clean Up and Structure probes passed; mocked AI tests remain explicitly separate. Final result bundle: `/tmp/MeetrailP11/Logs/Test/Test-Meetrail-2026.10.24_13-19-46-+0200.xcresult`; log: `/tmp/meetrail-p11-final-tests.log`. An intermediate post-cleanup run correctly skipped the missing-fixture integration test; fixtures were restored and the final complete run above performed it successfully.

```sh
Tools/run-calendar-qa.sh
xcodebuild -project Meetrail.xcodeproj -scheme Meetrail -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/MeetrailP11 \
  -parallel-testing-enabled NO test
xcodebuild -project Meetrail.xcodeproj -scheme Meetrail -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/MeetrailP11 build
xcodebuild -project Meetrail.xcodeproj -scheme Meetrail -configuration Release \
  -destination 'platform=macOS' -derivedDataPath /tmp/MeetrailP11Release build
python3 Tools/verify-architecture.py
git diff --check
Tools/run-calendar-qa.sh --cleanup
```

Both standalone builds passed for the final sources; logs are `/tmp/meetrail-p11-debug.log` and `/tmp/meetrail-p11-release.log`. Only the unrelated AppIntents metadata-extraction warning remains. Architecture/design-token verification and `git diff --check` pass. PolyForm LICENSE.md remains byte-identical. No dependencies, production calendar-writing capability or external AI were added. Private backups, exports, manifests and real data remain outside Git. All P11 repository screenshots are synthetic.

New coverage: day-scoped recovery and hidden-calendar exclusion; same-series history/context after event disappearance; persisted AI preference and suggestion safety; five-minute notification timing/replacement/cancellation; AI Apply/Cancel and disabled state; right-click Settings/Quit; compact single-card bottom bounds; per-step onboarding heights. Light/dark testing now verifies screenshot colors, and actual light agenda/editor/Settings/connections were inspected. Additional captures: [light agenda](P11-after-agenda-light.jpg), [light editor](P11-after-notes-light.jpg).

Files affected by P11 are limited to App window/composition code, existing design-system tokens/components (including a rendered-content scroll component), Agenda/MeetingDetail/Settings/Onboarding/CalendarAccounts Views and ViewModels, relevant note-retrieval/preferences/action protocols/use cases, the notification adapter's lead time/test boundary, tests and existing documentation. Removed: both NotesLibrary files, their feature directory, standalone notes routes, embedded Settings route, onboarding reset route, footer/visible Quit/duplicated close controls and obsolete estimated-height state. Calendar adapters, matching/recurrence algorithms, SwiftData schema and Foundation Models implementation were not changed by P11.

The final normally signed Release app is available at `/tmp/MeetrailP11Release/Build/Products/Release/Meetrail.app` for manual review. No install, login registration, branch, commit, push or publication was performed. Full spoken VoiceOver output and visible OS notification banners remain unverified; follow Docs/QA.md rather than treating automated interaction or notification-client tests as those checks. Other physical displays and macOS 15 runtime execution retain their earlier manual status.
