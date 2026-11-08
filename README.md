# Kaigi

**Your meetings. Your notes. All connected.**

Kaigi (会議, “meeting”) is a native macOS menu bar app for meetings and private occurrence notes. The initial free configuration includes local SwiftData storage, autosave, calendar management, reminders, Markdown export and launch at login.

## Build and run

Use Xcode 26 or newer with the macOS SDK. The app targets macOS 15 or newer; macOS 15 runtime compatibility still requires validation. Internal all-enabled AI testing requires macOS 26 or newer, supported Apple Intelligence hardware and language, Apple Intelligence enabled, and a ready model. AI is unavailable in the free configuration.

Open `Kaigi.xcodeproj`, select the **Kaigi** shared scheme and **My Mac**, then build and run. Local signed builds require a development team and signing identity available to Xcode. The project uses automatic signing. Before the first build, obtain the existing Firebase Apple app configuration from the owner and place it at `Kaigi/GoogleService-Info.plist` (ignored by Git); see [Analytics setup and privacy](Docs/Analytics.md). The build validates it without printing values. The required macOS Keychain Sharing capability needs a registered development Mac and matching profile.

```sh
xcodebuild -project Kaigi.xcodeproj -scheme Kaigi -configuration Debug build
xcodebuild -project Kaigi.xcodeproj -scheme Kaigi -configuration Release build
xcodebuild -project Kaigi.xcodeproj -scheme Kaigi -destination 'platform=macOS' \
  -parallel-testing-enabled NO test
python3 Tools/verify-architecture.py
python3 Tools/verify-swift-spacing.py
python3 Tools/test-analytics-release.py
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

The composition root injects one immutable, typed `FeatureToggles` value into ViewModels, application actions and window coordination. Views render their ViewModel's availability. Firebase Analytics and Crashlytics are the third-party product integrations. Feature availability has no mutable flag service, remote settings, payment state or persisted toggle values.

Calendar providers register through `CalendarAccountCoordinator`. Future provider identities are namespaced by provider, account, and calendar. The [design system](Docs/Brand/DesignSystem.md) documents adaptive purple/neutral colors, native typography, spacing, and controls. Every SwiftUI View modifier starts on its own line.

## Feature-toggle validation — 3 November 2026

On the local MacBook Pro (macOS 26.6.2, Xcode 27 / Swift 6.4), signed Debug and Release builds passed. All 52 unit tests and 18 UI tests passed (70 tests, zero failures or skips in the selected run). The real-calendar fixture integration test was explicitly excluded; no test calendar events or real-note edits were performed. The two synthetic transfer-data tests, architecture checker, Release-selector compilation probe, signature verification and `git diff --check` passed. The optimized Release executable contained none of the Debug override argument markers.

Visual review of synthetic XCTest captures covered free Light/Dark agendas, compact editors with export/Join/autosave, Settings without AI, the all-enabled editor and the enlarged-text bounded scroll viewport. Existing advanced history/context, carryover, revision, floating-editor and AI review tests ran with explicit all-enabled overrides. Test screenshots remain outside Git. The real-model cleanup probe also completed with synthetic input; that is an explicit test and does not enable AI in free mode or establish semantic accuracy.

The first UI attempt timed out awaiting macOS Enable UI Automation authentication; after the owner approved locally, the complete rerun passed. One new revision assertion was corrected to respect the existing 30-second checkpoint-coalescing policy; persistence behavior was not changed. XCTest emitted two internal QoS warnings without test failures. Spoken VoiceOver, macOS 15 runtime validation and live-calendar fixture integration were not rerun. Release UI behavior was established through the shared free-mode UI checks, the actual Release selector probe and binary inspection, rather than opening the owner's production store in a Release UI session. App Review compliance remains unresolved as described in the developer guide; no distribution action was taken.

## Accounts & Calendars UI validation — 4 November 2026

The accounts window uses a compact horizontal selector with one persistent purple indicator, animated only along its horizontal offset with a 0.25-second spring (bounce 0.1). Reduce Motion removes this movement. Native buttons retain selection announcements, focus feedback, and arrow-key navigation. Account disclosure indicators remain native; the label's hit region includes the title, count and intervening space. Group selection now uses a native mixed-state All checkbox with a regular label; its row preserves the previous bulk-action height. The ViewModel and calendar/data services are unchanged, and onboarding retains its existing presentation.

Only two authored vertical gaps change: heading-to-search **8 → 16 pt**, and search-to-list **8 → 16 pt**. The selector-to-section gap remains 16 pt; card-to-card spacing, card padding, expanded-content top padding, action-to-row spacing, row spacing and button internal padding remain 8 pt. The rendered selector remains 248 × 24 pt at default text size, the bulk-selection row remains 32 pt tall, and the search field's accessibility bounds remain 26 pt tall. Expanded content gains only a horizontal inset matching the measured native disclosure-title geometry (11.5 pt on this Mac at default text size); this is intrinsic alignment, not a new authored spacing value. Regular button text slightly reduces intrinsic button widths without changing padding or heights.

On macOS 26.6.2 / Xcode 27, signed Debug and Release builds, normal-keychain signature checks, all 52 synthetic unit tests, architecture verification, the Release feature-selector probe and `git diff --check` passed. Synthetic UI checks cover Light/Dark appearances, expanded/collapsed groups, title alignment, geometry invariants, whole-header clicks, checkbox and whole-account actions during filtering, hover feedback, keyboard navigation, enlarged text, provider cards and onboarding. Before/after screenshots and a cropped recording of the actual sliding indicator remain outside Git. No live calendar permission, production-store or external-service validation was performed.

The existing native Settings Command-comma UI test fails to open Settings on both the untouched baseline and the refined UI in this session; the status-menu Settings route passes. A broader UI run was interrupted after additional AI review, context text-entry, agenda and event-synthesis failures, so a full-suite pass is not claimed. Those tests were not removed or converted to skips. Spoken VoiceOver and macOS 15 runtime testing remain outstanding. Restricted-shell signing/trust checks required authorized runs with access to the existing development identity; no identities were created or revoked.

## Marketing sample profile and bulk selection

Expanded accounts expose one native **All** checkbox. Unchecked and mixed states select the whole account; checked deselects it. Its state uses the complete account catalog, including rows hidden by search. The existing visibility use case still preserves intentionally empty selections and temporarily missing IDs. The native AppKit checkbox supplies its checked/mixed/unchecked accessibility state, an account-specific label and Space activation. It keeps the former 32 pt bulk-action row at default text size; card padding, card gaps and individual calendar row spacing are unchanged.

Build and run an isolated Debug capture session:

```sh
xcodebuild -project Kaigi.xcodeproj -scheme Kaigi -configuration Debug \
  -derivedDataPath /tmp/kaigi-bulk-derived build
open -n /tmp/kaigi-bulk-derived/Build/Products/Debug/Kaigi.app --args \
  --sample --show-agenda --marketing-fixtures --test-session "$(uuidgen)" \
  -NSAppearance Aqua
```

Use `DarkAqua` for Dark Mode. Omitting `--test-session` creates a fresh random isolated session automatically; reusing an explicit identifier preserves that session's selection preferences. Notes remain in memory. No calendar permission is requested and no production store or EventKit calendars are written.

`--marketing-fixtures` is accepted only with `--sample` in Debug. It provides fictitious system-calendar groupings: **Work Account** (Work, Team Meetings, Project Reviews), **Personal Account** (Personal, Family, Birthdays), and **Subscribed Calendars** (Holidays, Travel). All eight calendars have distinct deterministic provider colors. Existing meeting occurrence IDs and conference links are retained, with the existing `sample` calendar presented as Work. The profile never implies direct third-party account integration, persists no fixture names or profile flag, and always uses `.appStoreFree`, even when combined with `--all-features`.

Normal `--sample` names and IDs are unchanged. If `--fifty-calendars` is also specified, the existing 50-calendar scale fixture takes precedence. Release compiles out the marketing factory and launch handling; marketing arguments cannot select synthetic providers in Release. Synthetic UI captures are validation screenshots only; no App Store artwork or website assets are generated by this workflow.

Validation on macOS 26.6.2 / Xcode 27 covers 60 synthetic unit tests and seven focused UI tests across selected runs: checkbox states/transitions, unfiltered bulk semantics, missing/unavailable IDs, empty-selection persistence, isolated automatic/explicit sessions, notes, Join dispatch, Light/Dark captures, normal and 50-calendar profiles, enlarged text, selector keyboard behavior and onboarding. Signed Debug/Release builds, signature verification, architecture checks, Release-selector compilation, absence of marketing flags/names in the Release executable, and `git diff --check` pass. Join dispatch is checked through an injected opener; no external conference was opened. Native accessibility role, account label, mixed value and Space activation are automated; spoken VoiceOver and macOS 15 runtime validation were not performed. Production stores, real EventKit calendars, and external services were not exercised.

## Analytics integration

Normal launches automatically use Firebase Analytics with a closed 25-event vocabulary. Calendar/note content, names, IDs, URLs, search terms and file paths are excluded from custom payloads. Firebase still collects installation identifiers, interaction/session information and device/app metadata; this is not anonymous or data-free analytics. IDFA/IDFV and advertising personalization are disabled. No custom user IDs/properties, Remote Config or Ads integration are added. Crashlytics automatic fatal diagnostics are described [separately](Docs/Crashlytics.md). See [the event specification, SDK disclosure audit, configuration setup and owner DebugView instructions](Docs/Analytics.md). App Store Connect privacy declarations and the website Privacy Policy require owner updates before distribution; this task does not modify the website or submit a build.

Synthetic Debug flags and XCTest hosts select NoOp and never configure Firebase; tests use spies and synthetic data. The early Settings dependency construction stays intact, with SDK configuration in the existing macOS delegate before tracker activation and window startup. `Tools/verify-analytics-bundle.py` checks actual bundled configuration, privacy Booleans, entitlements and dependencies. The formatting guard checks declaration blank lines without adding a formatter dependency.

### Verification — 5 November 2026

On macOS 26.6.2 / Xcode 27.0, final signed Debug and Release builds passed. All **72 synthetic unit tests** passed, including the 25-event catalog, every parameter variant, permission/export/settings outcomes, disabled operations, persistence, XCTest isolation and real native popover/window presentation deduplication. **Six focused UI tests** passed across selected runs: first status click, export cancellation with draft preservation, onboarding connection/selection/completion, native Settings → Connections, status-menu Settings/Quit, and calendar search/whole-account All selection across appearances. The full unrelated UI suite and separately provisioned live-calendar fixture test were not run; selected runs have no skipped tests. An initial new UI test targeted a Touch Bar Cancel element; the corrected window-scoped selector passes. A native regression test caught an immediate-popover-state timing issue; tracking now uses `popoverDidShow` and the regression passes.

Both final bundles pass configuration-equality/exactly-one-resource checks, generated Boolean privacy flags, bundle identity, signed sandbox/network/Keychain entitlements, absent advertising/Crashlytics libraries, and strict deep signature verification. Release contains no XCTest bundle or Debug QA selector markers. The existing development identity was used with normal automatic device/profile provisioning; no identities were generated/revoked. Architecture and Swift-spacing checks, compiled Debug/Release analytics selectors, the Release FeatureToggles selector, two synthetic data-transfer tests and `git diff --check` pass. Compiler isolation warnings around FeatureToggles default arguments and the no-AppIntents metadata warning remain; builds have no errors.

A real **non-synthetic Debug** launch with `-FIRDebugEnabled` stayed running and the SDK reported Analytics startup and collection enabled. It was then relaunched with `-FIRDebugDisabled`; only fixed status observations were retained, without Firebase configuration values. **DebugView receipt and parameter display are not verified:** Firebase Console redirected to Google sign-in. Follow [the exact owner checks](Docs/Analytics.md#debugview-owner-verification). Cloud project/stream settings, Google data-sharing/Ads links and retention require owner review. No real notes were edited, calendar permissions changed, conference destination opened, or real reminder/login setting changed for validation. Those flows have synthetic/injected coverage; live OS/external-service behavior, spoken VoiceOver and macOS 15 runtime remain unverified. No archive, upload or submission was performed.

## Crashlytics integration — 6 November 2026

FirebaseCrashlytics 13.1.1 is linked through the existing package alongside Core and AnalyticsCore. It initializes automatically through the unchanged single Firebase configuration call. The current merged plist adds the required macOS exception Boolean, and inherited linker flags include `-ObjC`. Both build configurations produce dSYMs; generic macOS Release contains arm64/x86_64. App source, startup/window behavior, Analytics events/policy, FeatureToggles, entitlements, package pin and SwiftData/user data are unchanged. No custom Crashlytics IDs/keys/logs or handled-error reporting are added.

**Locally verified:** signed Debug and universal Release builds, strict deep signatures, existing Firebase bundle checks, correct generated Info.plist/entitlements, Crashlytics static linkage and matching per-image/per-architecture dSYM UUIDs. The official SDK's validation-only mode passed in both configurations with script sandboxing enabled. Normal Release builds confirm the uploader is skipped. All 75 synthetic unit tests, four focused UI tests (first agenda click, native Settings/Connections, onboarding and export cancellation), four offline Crashlytics policy/refusal tests, architecture/spacing checks, both launch-selector probes, two data-transfer tests and `git diff --check` pass. The separately provisioned live-calendar test and full unrelated UI suite were not run; selected tests have no skips. The existing FeatureToggles actor-isolation/AppIntents metadata warnings remain.

**Not tested in Firebase Console:** receipt of a real crash or server-side symbolication. No deliberate crash, symbol upload or archive was performed. Symbol uploads default to NO; only a future owner-authorized Release install/archive with explicit opt-in runs the official uploader. The external verification tool refuses the owner's account and requires a clean disposable macOS account, signed Debug artifact and typed confirmations. No crash trigger is compiled into the app. Regional privacy/legal-basis review, App Store privacy declarations, website disclosure, live OS/calendar flows and macOS 15 runtime verification remain owner follow-ups. See [Crashlytics setup, file-by-file summary, privacy checklist, offline validation, upload/retry and safe manual verification](Docs/Crashlytics.md).

Additional offline checks:

```sh
python3 Tools/test-crashlytics.py
python3 Tools/verify-crashlytics-bundle.py /path/to/Release/Kaigi.app /path/to/Release/Kaigi.app.dSYM --production
```

## Crashlytics release audit — 8 November 2026

Xcode 27 built signed Debug and universal Release artifacts and a local development-signed Release archive for 1.0 (4). The archive uses the default SwiftPM tool location and passed Firebase’s validation-only command with script sandboxing enabled. The bundle checks verified Crashlytics and Analytics, one matching Firebase configuration, the macOS exception setting, signed entitlements, bundled privacy manifests and matching arm64 and x86_64 dSYM UUIDs. Release archives and explicit Release install actions now run the Firebase uploader in the foreground. See [Crashlytics](Docs/Crashlytics.md) for offline staging and retry commands.

The 75 unit tests, Crashlytics script tests, architecture and spacing checks, launch selectors, transfer tests and `git diff --check` passed. XCTest timed out while enabling macOS UI automation on both attempts, before the four selected UI cases could start. The compiler reported the existing FeatureToggles isolation and AppIntents metadata warnings. Live symbol upload, real crash delivery and symbolication in Firebase Console, App Store distribution signing, and macOS 15 runtime testing remain pending.

The Crashlytics uploader lookup now follows the project-specific `BUILD_DIR` for both Build and Archive. Signed Debug and Release builds passed after resolving pinned packages into fresh Derived Data. Development-signed archives from Xcode’s default layout and the fresh layout both passed the sandboxed Firebase validation-only phase and matched the arm64 and x86_64 dSYM UUIDs. The 75 unit tests and agenda startup UI smoke test passed. Live symbol upload and Firebase Console receipt remain pending. See [the relocated SwiftPM cache example](Docs/Crashlytics.md#upload-workflow).

## License and contribution rights

Copyright © 2026 Artemiy Kirillov. Licensed under [PolyForm Noncommercial 1.0.0](LICENSE.md). Kaigi is source-available; commercial use requires separate authorization. Contributor-rights agreements must be settled before merging outside work intended for commercial redistribution; see [CONTRIBUTING.md](CONTRIBUTING.md). Preserve all copyright/license notices.

No MeetingBar code/assets are used. Firebase is integrated through the existing Swift Package Manager dependency; preserve its and its transitive dependencies’ license notices. Provider artwork remains separately owned: preserve the [provider notices](Kaigi/Resources/ProviderArtworkNotices.txt) and bundled Microsoft Fabric Assets license. Apple's Calendar artwork is rendered locally and is not redistributed.
