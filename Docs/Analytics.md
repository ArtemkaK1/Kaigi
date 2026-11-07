# Firebase Analytics v1

Kaigi uses the existing Firebase Apple SDK **13.1.1** package reference (Analytics binary / GoogleAppMeasurement **13.0.1**). The app target links `FirebaseCore`, the IDFA-free `FirebaseAnalyticsCore` SPM product, and `FirebaseCrashlytics`; see [Crashlytics setup and privacy](Crashlytics.md). That product imports the `FirebaseAnalytics` module and transitively uses FirebaseInstallations, GoogleUtilities, nanopb and Promises. Resolved but unused package products are not app integrations. Remote Config, AdSupport, identity-support and on-device Ads conversion products are not linked. StoreKit is an upstream Analytics linker dependency; Kaigi adds no StoreKit or payment implementation.

## Initialization and isolation

The existing `@NSApplicationDelegateAdaptor(AppDelegate.self)` remains the sole native macOS delegate. Its initializer builds the dependency container with an inert tracker. `applicationDidFinishLaunching` calls `FirebaseApp.configure()` once, then enables that adapter, before starting window coordination. Constructors and refreshes emit no events. Tracking before activation is dropped, never queued. Event submission is synchronous and nonthrowing; SDK upload runs asynchronously and never gates app actions.

`AnalyticsLaunchPolicy` selects NoOp for XCTest hosts in both configurations. In Debug, **any** of `--sample`, `--marketing-fixtures`, `--all-features` or `--test-session` also selects NoOp, even without `--sample` and even with `-FIRDebugEnabled`. These launches do not configure Firebase, so automatic SDK events cannot contaminate the live project. Debug XCTest hosts additionally use the existing sample provider, isolated preferences and in-memory store. Tests inject a Spy into synthetic composition. Normal Debug and Release use the real tracker; Release ignores QA flags. `Tools/test-analytics-release.py` compiles the actual selector both ways without loading Firebase. FeatureToggles defaults and guards are unchanged.

`Configuration/Analytics-Info.plist` supplies actual Boolean privacy keys, merged with Xcode's existing generated Info.plist in both configurations:

- `FirebaseAppDelegateProxyEnabled = false`, as required by [Firebase's SwiftUI setup guidance](https://firebase.google.com/docs/ios/setup).
- `FirebaseAutomaticScreenReportingEnabled = false`; the custom presentation events below describe Kaigi's screens.
- `GOOGLE_ANALYTICS_IDFV_COLLECTION_ENABLED = false`.
- `GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS = false`.

The latter settings and the Core product follow [Firebase's collection controls](https://firebase.google.com/docs/analytics/ios/configure-data-collection). There is no custom user ID, user-property API call, app-generated installation ID, fingerprint, advertising identifier collection, Ads integration, remote setting, consent screen or analytics preference. Firebase itself manages automatic properties, including its non-personalized-advertising signal; these are distinct from app-created custom user properties. Analytics remains automatically enabled for normal use.

Outgoing sandbox networking and the app-scoped `$(AppIdentifierPrefix)com.volrik.kaigi` Keychain Sharing group are enabled. Firebase's macOS setup requires Keychain Sharing; no incoming-network entitlement is added. Automatic development signing may need a registered Mac and matching provisioning profile. Never generate/revoke certificates or remove the entitlement as a testing shortcut.

## Implementation map

| Files | Responsibility |
|---|---|
| `Domain/Models/AnalyticsEvent.swift`, `Domain/Protocols/AnalyticsTracking.swift` | Typed catalog, fixed payload mapping, protocol and NoOp |
| `Infrastructure/Analytics/FirebaseAnalyticsAdapter.swift` | Sole FirebaseAnalytics import; inert until configured |
| `App/StatusController.swift`, `DependencyContainer.swift`, `LiveComposition.swift`, `AnalyticsLaunchPolicy.swift` | Native startup, injected tracker, window presentation and test isolation |
| `App/KaigiApp.swift`, `WindowPresentationObserver.swift` | Observe the existing native Settings window without replacing its scene |
| Agenda, Onboarding, CalendarAccounts, MeetingDetail and Settings ViewModels; corresponding view action/lifecycle callbacks | All 25 user action/outcome events |
| `Domain/Protocols/Repositories.swift`, `Infrastructure/Export/WorkspaceServices.swift` | Explicit export success/cancellation with existing file contents/UX |
| Project file, entitlements, `Configuration/Analytics-Info.plist`, `Data/Preferences/AppPreferencesStore.swift` | Core-only products, local config validation, privacy/capabilities and first-onboarding marker |
| `KaigiTests/AnalyticsTests.swift`, `SpyAnalyticsTracker.swift`, `TestComposition.swift`, focused export UI test and `Tools/*analytics*`, `validate-firebase-config.py`, `verify-swift-spacing.py` | Deterministic tests, real-bundle checks, Release selection and narrow formatting guard |

Other existing Swift changes add declaration-separating blank lines and explicit NoOp injection in test constructors. README, SECURITY and AGENTS record setup/privacy/style requirements; `.gitignore`, package pin, persistent model definitions and license remain intact.

## Event specification

Names are stable lowercase snake_case, prefixed by the interaction's screen. Payloads are centralized in `Domain/Models/AnalyticsEvent.swift`; events accept only typed fixed values or Booleans. `enabled` is an integer, never a string. All unlisted parameters are absent; `source` is reserved but currently unnecessary.

| Event | Trigger | Parameters |
|---|---|---|
| `onboarding_started` | First actual onboarding presentation; a dedicated local Boolean prevents repeats across relaunch/reconstruction | — |
| `onboarding_connect_tapped` | Real calendar connection starts from onboarding | — |
| `onboarding_permission_result` | That request finishes | `result`: `granted`, `denied`, `error` |
| `onboarding_completed` | Transition to completed on Open Kaigi | — |
| `onboarding_skipped` | Explicit Skip for now; closing the window alone does not emit it | — |
| `menubar_agenda_opened` | Popover changes from closed to actually shown | — |
| `agenda_day_changed` | User changes the selected day; Today on today and automatic reset on popover opening do not emit | `direction`: `previous`, `next`, `today` |
| `agenda_meeting_opened` | User selects a meeting from the agenda | — |
| `agenda_join_tapped` | User invokes agenda Join, regardless of browser outcome | — |
| `agenda_recovered_note_opened` | User selects a recovered missing-event note | — |
| `notes_opened` | Occurrence editor appears; idempotent for its presentation session | — |
| `notes_edit_started` | First changed text-editor binding value in that session, including deletion; unchanged values/programmatic updates do not emit | — |
| `notes_join_tapped` | User invokes Join in the editor | — |
| `notes_export_tapped` | Enabled Markdown export begins | — |
| `notes_export_result` | Export finishes; success only after atomic file write, cancellation after save-panel dismissal, error after document/write failure | `result`: `success`, `cancelled`, `error` |
| `accounts_opened` | Connections page is presented, including switching back or reopening its window | — |
| `accounts_connect_tapped` | Real connection operation starts in Connections | — |
| `accounts_connect_result` | Operation finishes; inspect actual provider state for denial | `result`: `success`, `denied`, `error` |
| `calendars_opened` | Visible Calendars is presented | — |
| `calendars_search_used` | Search becomes non-whitespace; once until cleared or page/window interaction ends, never per character | — |
| `calendars_visibility_changed` | An individual calendar's selection actually changes | `enabled`: `1`, `0` |
| `calendars_all_changed` | All checkbox changes selection across the **entire account**, including search-hidden rows | `selection_state`: `all`, `none` |
| `settings_opened` | Native Settings window opens; refocusing an open window does not repeat it | — |
| `settings_reminders_changed` | Resulting effective setting changes after the async OS operation | `enabled`: `1`, `0` |
| `settings_launch_at_login_changed` | Resulting effective OS setting changes; rejected changes do not emit | `enabled`: `1`, `0` |

Opening Privacy Settings after denial is not a Connect request. Coming Soon providers and concurrent blocked connection attempts emit no Connect events. Disabled export/settings/window actions stay guarded; no advanced-feature events are added. Refreshes and SwiftUI body evaluation never emit analytics. Calendar selection, note revisions, context, legacy occurrence keys and persistence schemas are unchanged. One added preferences Boolean records initial onboarding presentation; existing preferences are retained.

Never add titles, calendar/account names, emails, attendee details, URLs, event/note IDs, note/generated text, revisions, search queries, filenames/paths, calendar dates/timestamps/durations, exceptions or arbitrary strings to payloads. Tests deliberately edit synthetic private-looking text and verify the closed payload vocabulary. Local session UUIDs used only to suppress editor duplicates are never transmitted or persisted.

## Local Firebase configuration

1. Obtain the **existing** Firebase project's Apple app configuration for `com.volrik.kaigi` from its owner / Firebase Console → Project settings → Your apps. Do not create a new project or application.
2. Save the unmodified download as `Kaigi/GoogleService-Info.plist`. The synchronized Kaigi source group includes it in Copy Bundle Resources automatically; do not add another copy phase/reference. The file remains ignored by Git. Do not paste its keys or IDs into documentation/logs.
3. Open the existing Xcode project, resolve the pinned SPM dependencies, select Kaigi / My Mac and the existing development team. Build Debug and Release normally. The early validation phase checks file syntax, bundle ID, app-ID/sender consistency, project-ID/API-key structure without printing values. Validation is local and cannot prove that a cloud project still exists or accepts events.
4. Inspect each final app with `python3 Tools/verify-analytics-bundle.py /path/to/Kaigi.app`. It checks configuration equality against the local file, exactly one bundled copy, identity, Boolean flags, required signed entitlements and unwanted libraries without revealing configuration values. `codesign --verify --deep --strict` independently checks signing.

A fresh clone intentionally needs this local file to build, including synthetic tests. Do not check in a substitute plist or fake production identifiers. No new secret service or CI workflow is required.

## SDK data and disclosure work

Content-free custom events do **not** make Analytics anonymous or data-free. [Google's SDK disclosure](https://support.google.com/analytics/answer/10285841) and [Firebase's data collection overview](https://support.google.com/firebase/answer/6318039) describe app-instance identifiers, interaction/session/engagement data, app/version/OS/device/language metadata and approximate geography derived from IP. FirebaseInstallations is also linked. Network requests necessarily expose transport metadata to Google; disabling IDFA/IDFV does not disable installation identifiers or all SDK collection. No claim of full anonymity is made.

Automatic lifecycle events can include `first_open`, `session_start`, `user_engagement` and `app_update`, subject to platform/SDK support. Kaigi does not manually duplicate them. Automatic screen reporting is disabled. Automatic purchases, campaigns or other SDK-supported events must be considered when applicable; Kaigi implements no purchases or campaign tracking. Crashlytics automatic fatal reporting is now configured through the same Firebase startup; the existing events can serve as breadcrumbs. See [its separate diagnostic disclosures](Crashlytics.md). Review [Firebase's disclosure guide](https://firebase.google.com/docs/ios/app-store-data-collection) and the exact shipped dependencies when updating the SDK.

The inspected macOS Analytics / GoogleAppMeasurement 13.0.1 frameworks do not contain standalone privacy manifests. Bundled FirebaseInstallations declares **Other Diagnostic Data**, unlinked, Analytics purpose; other bundled manifests declare no collected data, with required-reason UserDefaults/file-timestamp APIs in Core/Utilities. Absence of a vendor manifest is not evidence of no collection. Generate and review the archive privacy report before a future submission; no archive/submission is part of this task.

Before distribution, the owner must update:

- **App Store Connect → App Privacy:** disclose **Product Interaction**, **Device ID** (app/installation identifier even without IDFA/IDFV), **Coarse Location** (derived geography) for Analytics, and **Other Diagnostic Data** as applicable to FirebaseInstallations. Treat interaction/identifier data conservatively as linked to the installation/device; do not choose “not linked” merely because there is no login. Review actual SDK/configuration, retained metadata, linkage and any property-level sharing against [Apple's definitions](https://developer.apple.com/app-store/app-privacy-details/). Current app code adds no cross-company advertising tracking; verify Google property-level integrations/sharing before answering the tracking questions.
- **Website Privacy Policy:** replace any “no analytics/no network collection” claim. Identify Google/Firebase as analytics recipient, purposes, event categories, installation/device metadata, approximate geography, retention/deletion/contact procedures, international processing and applicable policy basis. Do not promise that notes or calendars are uploaded; the app excludes that content. The website is unchanged in this task.
- **App privacy documentation:** keep this spec, README and SECURITY aligned; retain SDK-manifest/required-reason API review evidence. Confirm the applicable notice/legal basis before distribution; automatic collection with no new opt-in UI is the requested product behavior, not a legal-compliance determination.

In the Firebase/Google Analytics property, the owner must verify that Google Ads links, Google signals, advertising personalization, user-provided-data collection and unnecessary Google data-sharing options are disabled. Set and document the intended retention/deletion policy. Code cannot inspect or change those console settings, and this integration does not enable them.

## DebugView owner verification

Use a **normal, non-synthetic Debug launch**. In Xcode → Edit Scheme → Run → Arguments Passed On Launch, enable `-FIRDebugEnabled`, with none of the four isolation flags. Do not add the debug argument to a shared production scheme. Normal launches use the real local note store and calendar permission state: avoid private editing solely for analytics testing.

1. Open Firebase Console for the existing project → Analytics → DebugView and select this Mac's debug device. The console and enabled Analytics stream must belong to the same downloaded configuration.
2. Open/close/reopen the agenda. Confirm one `menubar_agenda_opened` per actual open and none on refresh. Navigate previous/next/today, then Today again; verify only the three real changes and fixed direction values.
3. Select a harmless owner-chosen occurrence. Confirm `agenda_meeting_opened`, `notes_opened`, one `notes_edit_started` after actual editing, no per-keystroke events, and another editor-session pair only after leaving/reopening. Invoke Join only with an intended destination. If an existing recovered missing-event note is available, open it and verify `agenda_recovered_note_opened` followed by `notes_opened`; do not delete calendar events to force that condition.
4. Export: cancel once, then write to an owner-chosen location once. Verify `notes_export_tapped` followed by `cancelled` / `success`; induce a filesystem error only in a disposable directory if desired and verify `error`. File contents and export UX remain unchanged.
5. Open Settings, close/reopen it, visit Connections and Visible Calendars, search, clear/research, toggle one calendar and All during filtering. Inspect `enabled` as 0/1 and `selection_state` as all/none; restore the owner's original selections. No query/name/ID must appear. If the system provider is genuinely unconnected, use its Connect action and inspect the tapped/result pair after permission completes; Open Privacy Settings after a denial is not another connection request.
6. Change and restore reminders/login only if intended. Confirm resulting-state events, with none for rejected/redundant changes. Do not revoke calendar access, reset onboarding preferences or modify production notes to force rare outcomes. Initial onboarding and denied/error permission branches are covered by deterministic spies; live verification requires a genuine first-run or permission condition. Synthetic flags deliberately never report those events.
7. Inspect event parameters against the table, automatic events separately, and `non_personalized_ads = 1`. Verify there are no IDFA/IDFV/custom IDs/user properties or sensitive custom parameters. Confirm a `--sample -FIRDebugEnabled` session does not create new Firebase traffic.
8. Disable SDK debug mode by launching once with `-FIRDebugDisabled`, then remove both arguments. [Firebase DebugView guidance](https://firebase.google.com/docs/analytics/debugview) notes the setting persists; configure a developer-traffic filter if needed to exclude development events from reports/exports.

Console receipt must be checked by the owner when console access is unavailable to the agent. Local SDK initialization or upload logs alone do not establish DebugView delivery. See README for this task's factual verification results and remaining platform limits.
