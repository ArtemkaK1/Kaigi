# Firebase Crashlytics for macOS

## Status and scope

The 8 November 2026 audit verified a locally signed Release archive with Firebase’s validation-only uploader and script sandboxing enabled. Live symbol upload, crash delivery, Firebase Console symbolication, and App Store distribution signing remain pending.

The existing Firebase SPM package remains pinned at **13.1.1**. The Kaigi target links `FirebaseCore`, `FirebaseAnalyticsCore` and `FirebaseCrashlytics`; no second package/project/app is created. Crashlytics transitively adds FirebaseSessions, GoogleDataTransport and SDK interoperability protocols. `FirebaseRemoteConfigInterop` is a protocol dependency, not a Remote Config client or service integration. Auth, Firestore, Performance, Remote Config, AdSupport and additional advertising/attribution products are not linked.

The implementation follows Firebase's official [setup](https://firebase.google.com/docs/crashlytics/ios/get-started), [symbolication](https://firebase.google.com/docs/crashlytics/ios/get-deobfuscated-reports) and [customization/privacy controls](https://firebase.google.com/docs/crashlytics/ios/customize-crash-reports) guidance, checked against the installed package's `Crashlytics/run`, `upload-symbols --help` and eager default-app component registration.

## Startup and macOS configuration

`StatusController.swift` and the existing AppDelegate are unchanged. The sole `FirebaseApp.configure()` call runs in `applicationDidFinishLaunching` before the menu bar and window coordinator start. Crash capture begins at configuration, after the AppDelegate has constructed the dependency container. Configuration eagerly creates Crashlytics's default-app component, then Kaigi activates its existing inert Analytics adapter. No SDK wrapper, second delegate, extra configuration call, startup task, custom exception handler or blocking upload is added.

The app target preserves inherited linker flags and adds Firebase's required `-ObjC`. The existing generated Info.plist merges `Configuration/Analytics-Info.plist`, now with Boolean `NSApplicationCrashOnExceptions = true` in Debug and Release. This makes unhandled AppKit exceptions terminate as required for macOS crash capture; it does not turn handled Swift errors into crash reports. Existing Analytics flags remain false: delegate proxy, automatic screen reporting, IDFV and ad personalization signals. The sandbox, outgoing-network, calendar, user-selected file and app-scoped Keychain entitlements, signing, Hardened Runtime, macOS 15 minimum, bundle ID and legacy `Meetrail` module identity are unchanged.

There are no Crashlytics API calls in app/feature code: no custom user ID, keys, logs, non-fatal errors, explicit report sending/deletion or collection-toggle calls. Fatal reporting uses the SDK’s enabled default on normal launches. Crashlytics captures supported native crashes and fatal uncaught exceptions. The SDK also supports explicit non-fatal reporting through `record(error:)`. The existing manual tool exercises the fatal path.

## Synthetic QA isolation

The **unchanged** `AnalyticsLaunchPolicy` also protects Crashlytics. XCTest hosts never configure Firebase. Debug `--sample`, `--marketing-fixtures`, `--all-features` and `--test-session` launches select NoOp and skip configuration, even when flags occur individually. SDK class loading registers components but does not instantiate a reporter before the default Firebase app exists; automated tests verify the linked class and absence of that app without calling `Crashlytics.crashlytics()`.

As before, Release does not implement synthetic modes and ignores QA flags; it is always a normal live launch except for recognized XCTest hosts. Never use a Release launch with QA arguments as a safe synthetic session. FeatureToggles and all 25 Analytics events/parameters remain unchanged. Existing content-free custom Analytics events can become breadcrumbs, as can SDK automatic events; no duplicate crash-specific Analytics events are added.

## Symbol generation and offline checks

Both configurations now use `DEBUG_INFORMATION_FORMAT = dwarf-with-dsym`. Debug retains Xcode's debug-dylib arrangement: the dSYM contains both `Kaigi` and `Kaigi.debug.dylib`. Release built for generic macOS contains arm64 and x86_64 with matching symbol UUIDs. No stripping/signing/sandbox protections are disabled.

Run locally, substituting your build output directory:

```sh
python3 Tools/verify-analytics-bundle.py /path/to/Debug/Kaigi.app
python3 Tools/verify-crashlytics-bundle.py /path/to/Debug/Kaigi.app /path/to/Debug/Kaigi.app.dSYM
python3 Tools/verify-analytics-bundle.py /path/to/Release/Kaigi.app --production
python3 Tools/verify-crashlytics-bundle.py /path/to/Release/Kaigi.app /path/to/Release/Kaigi.app.dSYM --production
codesign --verify --deep --strict /path/to/Release/Kaigi.app
```

These checks never upload. The Crashlytics verifier checks the Objective-C class metadata in every architecture of the app code, the generated exception Boolean, the collection defaults, the app and Crashlytics privacy manifests, and matching executable/dSYM UUIDs. The metadata check works on stripped archives. The Analytics verifier retains configuration equality, exactly one local plist resource, identity, privacy Booleans, entitlements and advertising-dependency checks; it now allows the intended Crashlytics product. Raw Firebase configuration values are not reported.

To investigate a UUID manually, use `xcrun dwarfdump --uuid` on the **exact shipped executable** and corresponding `Contents/Resources/DWARF/Kaigi` file. For Debug, also compare `Kaigi.debug.dylib`. A rebuilt binary with the same version number is not a replacement for the original build's dSYM.

## Upload workflow

The final build phase calls `Tools/upload-crashlytics-symbols.sh` with User Script Sandboxing enabled. The input lists declare the dSYM bundle, its main DWARF image and Info.plist, the bundled GoogleService-Info.plist, and the app executable. Debug adds the debug dylib’s DWARF image. The phase also declares the wrapper and SDK uploader as inputs. [Firebase’s Xcode input requirements](https://firebase.google.com/docs/crashlytics/ios/get-deobfuscated-reports)

The default checkout path uses `$(SDK_STAT_CACHE_DIR)/SourcePackages/checkouts/firebase-ios-sdk`. Xcode 27 resolves that setting to the Derived Data root for both builds and archives. The old path based on walking up two levels from `BUILD_DIR` resolved inside ArchiveIntermediates during Archive. For an explicitly relocated SwiftPM cache, set `FIREBASE_SPM_CHECKOUT_DIR` to its Firebase checkout.

Release Archive and explicit Release install actions upload automatically by default. The script executes Firebase’s `upload-symbols --build-phase` in the foreground so Xcode receives the uploader’s exit status. This is the upload command used by Firebase’s `run` wrapper, which normally starts it in the background. Build-phase mode uses the same Xcode inputs and deduplication. Ordinary Debug and Release builds and XCTest skip the upload. Set `KAIGI_CRASHLYTICS_UPLOAD_SYMBOLS=NO` for offline staging, then upload the exact archive’s symbols manually.

### Validate without transmitting

`KAIGI_CRASHLYTICS_VALIDATE_SYMBOLS_ONLY=YES` takes precedence over the upload setting. It invokes only Firebase’s `upload-symbols --build-phase --validate`. The SDK prints a generic message about a background upload after validation. This invocation ends at validation.

```sh
xcodebuild -project Kaigi.xcodeproj -scheme Kaigi -configuration Release \
  -destination 'generic/platform=macOS' -archivePath /tmp/Kaigi-validation.xcarchive \
  KAIGI_CRASHLYTICS_VALIDATE_SYMBOLS_ONLY=YES archive
```

The audit used this mode to verify the actual Xcode archive environment with the default SwiftPM layout. The resulting archive had a development signature and matching arm64 and x86_64 dSYMs.

### Manual upload / retry — requires separate owner authorization

After the owner approves transmission of the specific build's symbols, use the **same pinned checkout** and the matching app/dSYM. This command actually uploads and has not been run in this task:

```sh
"$FIREBASE_SPM_CHECKOUT_DIR/Crashlytics/upload-symbols" \
  -gsp "$APP/Contents/Resources/GoogleService-Info.plist" -p mac "$DSYM"
```

`APP` and `DSYM` are owner-selected local paths. Do not paste the app ID/API key into flags, reports or source. Avoid verbose logs in public issues; symbols reveal code/source paths and should stay outside Git. For Debug verification, upload the Debug dSYM (including its debug dylib), not Release symbols. The official build-phase workflow uses the executable to detect duplicates without uploading the binary; retries must retain the same build artifacts and be checked in Console.

## Safe manual crash verification — not performed

A crash must be explicitly authorized first. Do not run it in the owner's normal macOS account, production store, XCTest host, sample mode, Release app or under Xcode/LLDB. There is **no test-crash code, button, argument, signal handler or automatic startup crash in the app**, even in Debug.

`Tools/crashlytics-verify-manually.py` is an external, interactive developer mechanism, outside every app target. It refuses accounts other than the dedicated disposable short name `kaigi-crash-qa`, CI/non-terminal/XCTest/injection sessions, unsigned or wrong apps, non-Debug artifacts, existing processes and an existing default note store. Debug is verified through the signed development entitlement and current Xcode debug dylib; the standard Release build has neither. Refusals are not successful crash reporting. Automated tests check refusal/gates only and never send a crash signal.

After authorization:

1. Create a **fresh disposable macOS account** with short name `kaigi-crash-qa`. Never rename/reuse the owner's account. Do not sign into calendars, import notes, transfer a sandbox or enter personal content there. The existing Firebase app/project configuration stays the same; do not register another app/project.
2. Build signed Debug with dSYMs normally. With separate upload authorization, upload **that build's** matching Debug dSYM using the command above. Local UUID checks alone do not upload or symbolicate on the server.
3. In Terminal in that disposable account, run `python3 Tools/crashlytics-verify-manually.py /path/to/Debug/Kaigi.app`. It will not run successfully in the owner's current account or from a noninteractive command. Type `LAUNCH KAIGI DISPOSABLE SESSION` to start the actual app with **no synthetic flags and no attached debugger**.
4. Wait for the menu bar app to finish starting. Do not connect calendars, write notes or change settings. Only then type `CRASH KAIGI DISPOSABLE SESSION`. The tool sends SIGABRT solely to its own still-running Debug child. Nothing crashes automatically at launch or after a timer. Cancelling the prompt leaves the disposable app running so it can be quit normally.
5. Relaunch **the same Debug app normally**, without the verification tool, debugger or synthetic flags. Keep it running online long enough for Crashlytics to process/send the pending report. Do not delete the disposable sandbox before this step.
6. Open the existing Firebase project's **Crashlytics** dashboard. Find the new native crash for that version/build and time. Confirm readable app frames, the correct build UUID/architecture, no missing-dSYM warning and no custom sensitive keys/logs/IDs. Inspect SDK automatic breadcrumbs separately from the unchanged custom event vocabulary. A report appearing without readable app symbols is not completed verification.
7. If absent, use Firebase's [test-crash debugging procedure](https://firebase.google.com/docs/crashlytics/ios/test-implementation), inspect local SDK/network logs privately, and check the troubleshooting table below. Do not claim receipt until the actual Console report is visible. Clean up only the disposable account/session after verification; never delete/reset a production store. The tool cannot be reused against an existing note store without owner-managed disposable-account cleanup.

This external mechanism has no binary trigger to remove after testing. It is not a mock Crashlytics client and does not claim server success. A SIGABRT report exercises the real native reporter and symbol pipeline; do not use SIGKILL. No special analytics identifiers, configuration or UI are introduced into Release.

## Troubleshooting

| Symptom | Check / recovery |
|---|---|
| Missing dSYM | Confirm `dwarf-with-dsym`, retain the original build's dSYM and compare each image/architecture UUID. Check Debug dylib as well as launcher. Upload only after owner approval. |
| UUID mismatch | Locate the original build's symbols. Matching app version alone is insufficient; never substitute a new rebuild. |
| Wrong Firebase app | Run both bundle verifiers, confirm exactly one unmodified local config for `com.volrik.kaigi`, and select the corresponding Console app/project. Do not print configuration values. |
| Missing GoogleService-Info.plist | Follow Analytics local setup. The early validator requires the intentionally ignored file; do not generate a fake config or add another resource copy. |
| Script sandbox denied access | Check the configuration-specific input list, resolved dSYM/executable/config paths, SDK tool inputs and cache override. Keep sandboxing enabled. Validation-only mode reproduces the real sandbox without upload. |
| Upload skipped | Ordinary builds and tests skip uploads. For Archive, check the Release configuration and both Crashlytics build flags. |
| Offline / failed network upload | Routine builds work offline with cached dependencies. A Release upload needs network; inspect private vendor logs and retry the exact dSYM manually after approval. |
| Duplicate upload | Ensure only one build phase, use its executable input for vendor deduplication, and check Console before retrying. Do not add another upload script. |
| No report | Ensure a real authorized supported crash, no attached debugger, normal live configuration, subsequent normal relaunch and network access. Synthetic launches intentionally cannot verify reporting. |
| SDK class exists in tests | Expected: ObjC registration is linked. No default Firebase app means no eager reporter initialization or production reporting. Never call the singleton to test its absence. |

## Privacy and distribution checklist

Automatic crash reports are **not anonymous merely because Kaigi has no accounts**. They include stack traces/application state, device/OS/app information, crash/session/installation identifiers and potentially Analytics breadcrumbs. The app sends no custom meeting/calendar/account names, email, attendee details, event/note IDs, note/revision text, URLs, filenames/paths, search queries, installation IDs, raw Swift errors, custom keys or custom logs. Handled application errors are not recorded as non-fatals. Automatic system exception reasons, binary images, symbol/source references and other SDK diagnostic context must be assessed separately; absence of custom fields is not a promise that every automatic report is free of identifying information.

The archive contains Kaigi’s first-party `PrivacyInfo.xcprivacy` for app-local UserDefaults and the manifests from Crashlytics, Firebase Core and Installations, and GoogleDataTransport. The pinned macOS Analytics and GoogleAppMeasurement frameworks have no standalone manifest in this archive. Use the SDK disclosures alongside the archive report.

The inspected 13.1.1 Crashlytics privacy manifest declares **Crash Data** and **Other Diagnostic Data**, App Functionality purpose, unlinked and not used for tracking, with UserDefaults reason CA92.1. Its GoogleDataTransport dependency declares Other Diagnostic Data for Analytics, unlinked/not tracking. FirebaseSessions and installation/session identifiers must also be considered; do not infer no collection from absence of a standalone manifest. Analytics's existing disclosures still apply. Firebase's [Apple disclosure guide](https://firebase.google.com/docs/ios/app-store-data-collection) and [Apple's definitions](https://developer.apple.com/app-store/app-privacy-details/) require labels based on the app's actual integrations and linkage, not just vendor defaults.

Before public distribution, the owner must:

- [ ] Add **Diagnostics → Crash Data**, purpose **App Functionality**, in App Store Connect → App Privacy.
- [ ] Review/add **Diagnostics → Other Diagnostic Data** for Crashlytics health/session diagnostics (App Functionality) and transport metadata (Analytics), retaining existing Analytics/Installations declarations.
- [ ] Review **Usage Data → Product Interaction**, **Identifiers → Device ID**, and **Location → Coarse Location** for Analytics events, the app-instance identifier, and approximate geography. Review device ID coverage for Crashlytics SDK-managed identifiers as well. No custom account/user ID is added. Assess linkage of crash data and breadcrumbs to installation/device identifiers; do not automatically label all data “not linked” based solely on no login or the vendor manifest.
- [ ] Review SDK/Google property practices against Apple's tracking definition. This change introduces no advertising/cross-company tracking API, but existing Console sharing/integrations must be reviewed by the owner.
- [ ] Review the privacy report from the final distribution archive. The local audit archive includes Kaigi’s UserDefaults reason `CA92.1` and the SDK manifests listed above.
- [ ] Update website Privacy Policy before distribution with the text below, plus accurate retention/deletion/contact/transfer details. Do not publish placeholder durations or an invented contact address.
- [ ] Confirm regional notice/legal-basis/consent requirements, international processing and Google/Firebase contractual terms. Automatic reporting with no new consent UI is requested product behavior, not a legal determination. These questions remain unresolved pending owner review.

Suggested website policy text for the separate follow-up (not published here):

> Kaigi uses Google Firebase Crashlytics to diagnose crashes and improve app reliability. Crash reports can include stack traces, relevant application state, app version, device and operating-system information, SDK-generated crash/session/installation identifiers, and recent usage events from Firebase Analytics. Kaigi does not set a custom Crashlytics user ID or intentionally attach meeting or calendar content, note text, account details, search queries, meeting links or local file paths to reports. Automatically generated diagnostic context may still contain identifying information. Diagnostic data is processed by Google/Firebase and is not fully anonymous. Our retention, deletion, contact and international-processing information applies to this diagnostic processing as described in this policy.

The final sentence needs the owner's actual policy sections and practices. The separate website repository, App Store metadata/screenshots, consent UI and tracking preferences are unchanged.

## Changed files and verification record

| File | Change |
|---|---|
| `Kaigi.xcodeproj/project.pbxproj` | Existing-package Crashlytics product, inherited `-ObjC`, dSYMs in both configurations, foreground Release symbol phase and Archive-safe SwiftPM path |
| `Configuration/Analytics-Info.plist` | Required macOS exception Boolean in the existing merged plist |
| `Configuration/Crashlytics-Debug.xcfilelist`, `Crashlytics-Release.xcfilelist` | Sandbox inputs, including Debug dylib |
| `Tools/upload-crashlytics-symbols.sh` | Foreground Release upload and offline SDK validation branch |
| `Kaigi/PrivacyInfo.xcprivacy` | First-party declaration of app-local UserDefaults access |
| `Tools/verify-analytics-bundle.py` | Allow intended Crashlytics while retaining privacy/configuration checks and rejecting unwanted service/advertising frameworks |
| `Tools/verify-crashlytics-bundle.py` | Static linkage, actual plist and per-image/per-architecture dSYM UUID checks; Release trigger exclusion |
| `Tools/crashlytics-verify-manually.py` | External account/Debug/interactive-gated crash verification, never executed for a crash in this task |
| `Tools/test-crashlytics.py`, `KaigiTests/CrashlyticsTests.swift` | Safe build-policy, upload/refusal, runtime isolation and generated-plist tests |
| `Docs/Crashlytics.md`, `Docs/Analytics.md`, README and SECURITY | Setup, upload/recovery, privacy, verification and remaining owner steps |

Application Swift source, lifecycle/window coordination, AnalyticsLaunchPolicy/catalog, FeatureToggles, entitlements, package pin, SwiftData models/store location and existing user data are unchanged. See README for final local validation results; Firebase Console receipt/symbolication remains **not tested**.
