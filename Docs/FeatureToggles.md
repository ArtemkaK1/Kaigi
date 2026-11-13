# Feature access

`FeatureToggles` is an immutable rollout configuration. `.released` explicitly lists the capabilities shipped in Kaigi. Adding a case to `AppFeature` requires a decision in the exhaustive access policy and a separate decision in the release allowlist. `.allEnabled` is an explicit QA configuration.

`EntitlementStore` observes an injected `EntitlementProvider` and starts in `.loading`. The provider publishes initial and subsequent states on the main actor. Normal launches use a provider that resolves `.free`. App composition shares one `FeatureAccess` and its store with the dependency container, router, window coordinator, and feature use cases.

`FeatureAccess.status(of:)` returns `.unavailable` for a disabled rollout, `.loading` while Pro access is unresolved, `.requiresPro` for a released Pro feature on Free, or `.available`. `allows(_:)` is the same decision in Boolean form. Free capabilities stay available during loading.

| Tier | Capabilities |
|---|---|
| Free | Menu bar agenda and day navigation, system calendar connection and management, calendar search and selection, conference detection and Join, occurrence notes and autosave, missing-event recovery, Markdown export, reminders, launch at login, revision history and restoration, onboarding, Settings, keyboard shortcuts, and accessibility. |
| Pro | Meeting-scoped history (`meetingHistory`), recurring context workflows (`recurringContext`), floating notes (`floatingNotes`), AI Clean Up (`aiCleanUp`), and AI Structure (`aiStructure`). |
| Unavailable | Direct Google, Microsoft/Outlook, Yandex, Zoho and CalDAV connections, unfinished capabilities, and synthetic providers or mock AI in production. |

## Runtime behavior

SwiftUI observes the entitlement through ViewModel access properties. The container refreshes history and context on existing editors. The window coordinator closes History & Context when both capabilities are inaccessible and returns open floating panels to ordinary window level, keeping their editor and draft. Users with Pro can explicitly float those windows again.

History and recurring context can independently expose the combined window. Opening a historical occurrence in a floating editor requires both history and floating access. **Previous Notes** uses the same series ID, excludes the current occurrence key, and includes saved records with nonblank note text or confirmed context. It sorts by the saved occurrence start, newest first, with the occurrence key breaking ties. The start must precede the selected occurrence and be no later than the current time. Day navigation remains available independently.

Context confirmation, carryover, and per-series context preferences require recurring context access. The ordinary note editor displays saved confirmed context in a read-only section and Markdown export includes it. Unconfirmed context drafts stay in the cached editor during entitlement changes and can be read or copied from the ordinary editor while access is paused. They stay in memory for the session. Kaigi asks before quitting with unconfirmed drafts. Revision creation, browsing, and restoration are Free.

Each AI action checks its own access and also respects the user's AI preference and the model's OS and Apple Intelligence requirements. Entitlement loss cancels active refinement, invalidates pending and ready results, and preserves any result the user already applied. Context carryover works independently of AI.

## QA

- `--sample --show-agenda` opens a synthetic Free session with in-memory notes.
- Add `--simulate-entitlement` to start in Loading. Right-click the menu bar icon and choose **Simulate Loading**, **Simulate Free**, or **Simulate Pro**. The session can change state repeatedly.
- `--sample --all-features` keeps the existing advanced QA shortcut and starts in Pro. It can be combined with `--simulate-entitlement` to show the controls. `--context-history` and `--mock-ai` provide synthetic fixtures.
- These overrides are Debug-only and excluded from the marketing fixture profile. Simulated entitlement is held in memory. The Release launch policy resolves Free regardless of QA arguments.
- Unit tests default to Free. Advanced tests inject rollout and entitlement explicitly, for example `TestComposition(features: .allEnabled, entitlement: .init(.pro))`. Runtime tests use a provider that can publish states deterministically. Run `python3 Tools/test-feature-toggles-release.py` to compile and exercise the real launch policy without DEBUG.

## Kaigi Pro window

Settings always offers a compact Kaigi Pro row. It reports **Checking access…**, **Coming Soon**, or **Active** from the current entitlement. The shared native window describes released capabilities. Its Free footer explains the planned one-time purchase and current purchase availability. The Active and Loading footers reflect access without purchase messaging.

`ProPresentationPolicy` enables contextual entry points in synthetic Debug sessions launched with `--sample --simulate-entitlement`. It evaluates `.requiresPro` through `FeatureAccess` at presentation and routing time. History & Context, Floating Notes, Clean Up, and Structure open the same window from the editor. Loading and unreleased actions stay hidden. The standard actions retain their execution checks. The right-click status menu and the **Entitlement QA** app menu can change access while the window is open.

The window coordinator keeps one Pro window, reuses it while visible, and returns focus to its source when dismissed. Opening it from the agenda preserves the selected day and editor. The window sizes to measured content and caps scrolling above the footer on shorter screens. The Pro reading width is 480 pt before the display cap.

## P3

Inject a StoreKit 2 provider in App composition to publish verified ownership and revocations. Supply localized product data, handle purchase and restore outcomes, and enable contextual entry points when purchase is available. The shared Pro window, route, ViewModels, and execution guards use the existing access interfaces.
