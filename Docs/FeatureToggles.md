# FeatureToggles

`Domain/Models/FeatureToggles.swift` defines `AppFeature` and an immutable, Sendable value containing a private `Set<AppFeature>`. `isEnabled(_:)` is the typed availability check. There is no global mutable state, service locator, persistence, network configuration, macro or external dependency.

## Matrix

| AppFeature | appStoreFree (default) | allEnabled |
|---|---|---|
| calendarManagement | enabled | enabled |
| meetingReminders | enabled | enabled |
| markdownExport | enabled | enabled |
| launchAtLogin | enabled | enabled |
| meetingHistory | disabled | enabled |
| recurringContext | disabled | enabled |
| aiCleanUp | disabled | enabled |
| aiStructure | disabled | enabled |
| revisionHistoryUI | disabled | enabled |
| floatingNotes | disabled | enabled |

Daily agenda, day navigation, system calendar reading, conference Join, occurrence notes, editing/autosave and missing-event note recovery are core behavior, without toggles. Ordinary calendar recurrence indicators remain visible.

History and recurring context are independent. Either opens the existing meeting-scoped History & Context window. `meetingHistory` exposes occurrence selection/read-only earlier notes; `recurringContext` exposes confirmation, previous confirmed context, carryover and the per-series preference. Editing an earlier note via Open note additionally requires `floatingNotes`. Context-only mode has no occurrence sidebar. History-only mode has no context sections. Neither requires AI or revision UI.

Clean Up and Structure are independent; either enables the shared AI preference and review surface. Each processing action checks its own toggle, and Apply checks the originating action. The user's AI preference is an additional requirement and is never reset by availability. Internal revisions continue regardless of `revisionHistoryUI`. Free Markdown export contains the current note without exposing the disabled confirmed-context section; stored context is unchanged and available again with the relevant configuration.

## Composition and guards

`LiveComposition` supplies `.forLaunch(arguments:)` to `DependencyContainer`; the container owns a `let features` and passes the same value to Agenda, Settings, MeetingDetail and the reminder-loading use case. App composition supplies the same selection to `AppRouter`; `AppWindowCoordinator` checks its container's value before opening gated windows. No feature constructs a concrete adapter to obtain availability.

Views conditionally render controls/sections using their ViewModel's immutable availability. ViewModels guard refinement/apply, revision restoration, history selection, context confirmation/carryover/preferences, floating windows, export and optional settings. Application actions and window routes guard again. A stale presentation Boolean cannot authorize an operation, and configurations cannot mutate under an existing window. No disabled history/context data is loaded into the presentation arrays. Core persistence and provider adapters are unchanged.

Normal Debug launches and all Release launches select `.appStoreFree`. The only launch override is `--sample --all-features`, compiled solely under `#if DEBUG`; it uses the existing synthetic calendars, in-memory notes and QA preference suite. `--all-features` without `--sample` does nothing. No environment variable, date, account, user preference or remote service selects advanced features. Release contains no Debug override path.

## Tests and adding a toggle

Tests default to free. Advanced tests opt in explicitly:

```swift
let free = try TestComposition()
let internalReview = try TestComposition(features: .allEnabled)
let cleanupOnly = try TestComposition(features: FeatureToggles(enabled: [.aiCleanUp]))
```

UI tests use `launch(["--all-features"])` for advanced scenarios; their helper already supplies `--sample`. Free UI tests omit the override. `FeatureTogglesTests` exercises every case, independent/custom sets, blocked actions/window routes, same-store configuration changes, retained context/preferences, autosave and revisions. Existing advanced tests remain active. `Tools/test-feature-toggles-release.py` compiles the actual selector without DEBUG and verifies that all QA arguments resolve to free.

Validation on 3 November 2026: signed Debug/Release builds, 52 unit tests, 18 UI tests, two transfer-data tests, the architecture checker, the Release selector probe, signature verification and `git diff --check` passed. The selected Xcode run had zero failures/skips; the separately provisioned live-calendar fixture test was excluded. Free Light/Dark screenshots and all-enabled captures were inspected outside Git. See README for environment limits and the distinction between Debug UI testing and Release selector/binary verification.

To add a capability, add one explicit `AppFeature` case, choose its free default, inject the existing value where needed, gate the presentation and every action/window route, then update this matrix and positive/negative tests. `allEnabled` includes all cases automatically. Do not create an umbrella `isPro` flag or disable internal recovery mechanisms.

## Future entitlement boundary

No StoreKit or monetization code is implemented. A future verified entitlement use case could produce a new `FeatureToggles(enabled:)` value at the App composition boundary. Existing Views and ViewModels would consume the same typed checks. Applying a new immutable configuration would require deliberate replacement/recomposition of affected presentation models/windows while preserving/flushing note drafts; this task does not implement live entitlement updates. Availability stays independent of how an entitlement is obtained or verified.

## Distribution risk (checked 3 November 2026)

Apple's current [Guideline 2.5.19](https://developer.apple.com/app-store/review/guidelines/#software-requirements) prohibits hidden, dormant or undocumented functionality. Fixed local runtime toggles and the absence of purchases/remote activation do **not** establish approval. Advanced source remains compiled in the app, so binary-level dormant-functionality review remains an outstanding distribution risk. No archive, upload or submission was performed.

A minimal follow-up, if required for distribution, is an explicit internal-build compilation condition around advanced UI/operation/window paths and AI adapter inclusion. Keep the source and all persistent model declarations, internal revision creation, occurrence/series identities and storage code shared. Verify the exact Free Release binary rather than relying on dead-code stripping, and disclose the actual shipped behavior in review notes. This change does not introduce compile-time restructuring or conceal functionality from review. Current user-facing README capabilities describe the free configuration; website and App Store screenshots were not changed and must be checked separately before a future submission.

## Changed files

| File | Change |
|---|---|
| `Kaigi/Domain/Models/FeatureToggles.swift` | Typed capability registry, immutable sets and explicit free/all defaults. |
| `Kaigi/App/FeatureToggles+Launch.swift` | Fixed Release selection; sample-only Debug override. |
| `Kaigi/App/DependencyContainer.swift` | Own and inject availability into existing presentation/use-case dependencies. |
| `Kaigi/App/LiveComposition.swift` | Select configuration for live composition. |
| `Kaigi/App/StatusController.swift` | Guard application routes, exports and account/context/floating windows. |
| `Kaigi/Domain/UseCases/NoteUseCases.swift` | Optional context inclusion in export; guard reminder scheduling. |
| `Kaigi/Features/Agenda/AgendaViewModel.swift` | Suppress advanced context badges; guard management navigation. |
| `Kaigi/Features/Agenda/AgendaView.swift` | Hide unavailable management buttons. |
| `Kaigi/Features/MeetingDetail/MeetingDetailViewModel.swift` | Guard each advanced action, independent AI operations and history/context loading. |
| `Kaigi/Features/MeetingDetail/NoteEditorView.swift` | Hide unavailable controls and entire empty sections. |
| `Kaigi/Features/MeetingDetail/MeetingContextView.swift` | Independently gate occurrence history, context and floating edit actions. |
| `Kaigi/Features/Settings/SettingsViewModel.swift` | Guard optional preference changes without resetting stored values. |
| `Kaigi/Features/Settings/SettingsView.swift` | Render only available preference controls/divider. |
| `KaigiTests/TestComposition.swift` | Default-free test fixture with explicit configuration injection. |
| `KaigiTests/FeatureTogglesTests.swift` | Matrix, overrides, blocked routes, independent capabilities and preservation tests. |
| `KaigiTests/UICleanupTests.swift` | Explicit all-enabled injection for retained advanced scenarios. |
| `KaigiTests/StabilizationTests.swift` | Explicit all-enabled injection for retained AI/shared-editor scenarios. |
| `KaigiUITests/KaigiUITests.swift` | Free Light/Dark checks and positive all-enabled checks; explicit advanced-test overrides. |
| `Tools/test-feature-toggles-release.py` | Compile and execute the Release selector without DEBUG. |
| `README.md` | Accurate free capabilities, developer-guide link and QA instructions/results. |
| `AGENTS.md` | Availability injection and preservation rules for subsequent changes. |
| `Docs/FeatureToggles.md` | Matrix, architecture, extension guide, validation and distribution risks. |
