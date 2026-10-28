# Kaigi rebranding validation — 28 October 2026

## Scope and renamed components

The existing project was renamed in the current checkout; its Xcode object IDs, target dependencies, Debug/Release configurations and capabilities were retained. No replacement project was generated. No branches, commits, pushes, repository rename, visibility changes, release, archive upload, TestFlight upload, App ID creation, certificate generation/revocation or website edits were performed.

| Component | Result |
|---|---|
| Project and synchronized source group | `Kaigi.xcodeproj`, `Kaigi/` |
| App target, product, executable, display name | `Kaigi`, `Kaigi.app`, `Contents/MacOS/Kaigi`, `Kaigi` |
| App entry file/type | `Kaigi/App/KaigiApp.swift`, `KaigiApp` |
| Shared build/test/profile/archive scheme | `Kaigi` |
| Unit target/group/primary suite | `KaigiTests`, `KaigiTests/KaigiTests.swift` |
| UI target/group/suite | `KaigiUITests`, `KaigiUITests/KaigiUITests.swift` |
| Entitlements | `Kaigi/Kaigi.entitlements` (contents unchanged) |
| App bundle ID | `com.volrik.kaigi` |
| Test bundle IDs | `com.volrik.KaigiTests`, `com.volrik.KaigiUITests` |
| Test host/loader/dependencies | Kaigi app/executable, original target IDs retained |
| Icon source / selected icon name | `Kaigi/Kaigi.icon` / `Kaigi` |
| Fallback icon catalog / template symbol | `Kaigi.appiconset` / `KaigiStatus.imageset` |
| Shared button style | `KaigiButtonStyle` (one hierarchy; obsolete border/prominent booleans removed) |
| Tooling/documentation | Architecture source root, QA executable, startup traces, sample defaults suites, UI assertions, export filename, notices, README/AGENTS/security/contributing branding updated |
| Persisted Swift module | **`Meetrail` retained deliberately** |

No obsolete Meetrail project/shared scheme or orange icon sources/generator remain. The local checkout directory still has its original name as requested. Private Xcode UI state remains local/ignored; its old scheme title was updated. All source/resources were carried forward; the SwiftData repository, entitlements and bundled third-party license are byte-for-byte identical to their originals.

## Xcode editor compatibility

The final GUI check found that the repository's existing `objectVersion = 110` prevented installed Xcode 26.4.1 from opening it. Xcode 27's editor separately looked for a nonexistent `project.xcproj` while correctly reading/building `project.pbxproj`; the same behavior reproduced in an external temporary copy with versions 110 and 77. No diagnostic project was added to the repository.

The real project's header now uses **77**, matching its existing `preferredProjectObjectVersion = 77` and the property-list Xcode 16.0 compatibility setting. Parsed metadata comparison confirmed that this header is the **only semantic change** in that correction: all object IDs, targets, build settings and capabilities remain identical. The actual project opens cleanly in **Xcode 26.4.1 (17E202)**, with all three targets, Kaigi scheme, bundle ID and icon visible in [the editor capture](Brand/Previews/xcode-project.png). An additional signed Debug build in Xcode 26.4.1 passed. Final signed Debug and universal Release rebuilds in Xcode 27 also passed after the header change; application source is unchanged from the passing tests. Use Xcode 26.4.1 for the GUI if this Xcode 27 installation shows the editor lock. Its editor issue remains a tool-specific limitation; no speculative JSON conversion was applied. Apple's [format documentation](https://developer.apple.com/documentation/xcode/updating-your-xcode-project-configuration-file-format) describes the two formats; this repository retains its property-list project.

## Apple identity and signing

Before changing the bundle ID, the existing Apple Developer identifier list was read in Safari under team **WX557M9HD2**: **Kaigi → com.volrik.kaigi**. App Store Connect App Information independently showed **Kaigi - com.volrik.kaigi**, app name **Kaigi - Meeting Notes**, SKU `kaigi-macos`, Apple ID **6828158632**. The remote listing was read only and its exact name was preserved.

Both configurations keep **Automatic** signing and team **WX557M9HD2**. Marketing version **1.0** and build **1** were unchanged. The native About panel displays Kaigi and the new compiled icon. An authorized keychain read found the existing development identities; restricted-shell certificate/signature diagnostics were not treated as proof of missing or invalid identities. Authorized `codesign --verify --strict` confirmed the app signature and team.

App Sandbox, read/write access to user-selected export files and calendar entitlement are retained. Release disables injection of development base entitlements; XCTest adds its own debugging/test-manager allowances to the Debug test host. No extra production access was added. The calendar usage string names Kaigi and explicitly says that calendar events are never changed.

## Palette, controls and typography

[The full token table](Brand/DesignSystem.md) lists all Light/Dark colors, states and calculated contrast. Main colors:

| Role | Light | Dark |
|---|---|---|
| Background | `#F7F7FA` | `#1C1A20` |
| Surface | `#FFFFFF` | `#27242D` |
| Primary text | `#211E27` | `#F4F1F8` |
| Secondary text | `#66616F` | `#B6B0C0` |
| Accent | `#713BD1` | `#BE9AF6` |
| Primary fill / foreground | `#713BD1` / white | `#8146CC` / white |
| Secondary control | `#E9E6EF` | `#3A3444` |
| Border | `#D9D5E1` | `#4C4557` |

White on primary fill measures **6.46:1 Light / 5.70:1 Dark**; secondary text on surfaces **5.99:1 / 7.24:1**. Native shells retain macOS materials. Explicit root tint and matching AccentColor assets keep purple controls; the final UI test deliberately supplies an alternate system accent and checks purple Join/Links fills. Native filled checkbox/list selections use the darker `accentFill` token to retain white-glyph contrast; editor carets and accent text retain the lighter accent token.

Primary actions use purple fills, secondary actions use distinct neutral fills, and tertiary actions use quiet text/icons with no resting background/stroke. Hover/pressed fills, accessibility labels/help, hit geometry, keyboard shortcuts and focus treatment remain. Editor/text-field borders are retained. Native menus, checkboxes and segmented controls retain native behavior.

San Francisco remains the only app font, with scaled **11/13/16/20** roles. Semibold is reserved for headings, medium for important actions/selected states and meeting/provider labels, regular for text/metadata/times. No extra font sizes or dependencies were added. Content-sized agenda geometry and the bounded scroll viewport are preserved.

## Icon artwork and visual evidence

The owner's PDF was rendered and inspected; document contents were treated as visual reference, not instructions. Whole-icon concepts A1–A4 were explored with built-in Imagegen. The owner selected **A3** and requested clear vector edges; A4's glossier material was rejected. [Approval and protected invariants](../Tools/AppIcon/Kaigi/design-approval.yaml) record the named image and SHA-256.

- Editable shaded master: [SVG](../Tools/AppIcon/Kaigi/Kaigi-symbol-master.svg).
- Flat construction master: [SVG](../Tools/AppIcon/Kaigi/01-symbol.svg).
- Monochrome/template master: [SVG](../Tools/AppIcon/Kaigi/Kaigi-symbol-monochrome.svg).
- Native production source: [Kaigi.icon](../Kaigi/Kaigi.icon/icon.json), created/saved in actual Apple Icon Composer.
- [Native 1024 px export](../Tools/AppIcon/Kaigi/Exports/Kaigi-macOS-Default-1024@1x.png), size exports 16/32/64/128/256/512/1024 and six native appearance exports are under `Tools/AppIcon/Kaigi/Exports/`.
- [Appearance board](Brand/Previews/icon-appearances.png), [size ladder](Brand/Previews/icon-size-ladder.png), [native About panel](Brand/Previews/about-runtime.png).

The lower body uses two exact circular caps with straight tangent flanks; there are no traced raster edges, micro-corners or excessive anchors. SVG audits score **98/100** for flat geometry and **90/100** for the shaded master (the latter flags intentional gradients). Native Composer owns the #F5F5F5 backdrop, platform mask and soft shadow; SVG radial color fields preserve the approved matte surface. Specular/refraction/blur/translucency are disabled. Mono uses System Light for recognition. All six exported appearances were inspected and Mono contrast was refined after the first pass. The separate monochrome status image is marked template and never reuses the full-color tile.

The generic skill PNG preflight flagged native transparent macOS mask corners using an iOS-style opaque-master rule; this is documented rather than hidden. Native macOS output retains appropriate alpha, received an sRGB profile without pixel changes, builds through Xcode and was observed in the app. This is not an iOS App Store master or a claim of App Review approval.

## Data compatibility and transfer

[DataMigration.md](DataMigration.md) inventories sandbox/defaults/login/permission changes and provides an owner-mediated backup/import procedure. Nothing automatically crosses the sandbox boundary. The helper requires explicit source/destination paths, refuses running apps, consolidates only a copy of the old store, verifies checksums/integrity/entity counts, and refuses existing destination files. Keep old installations and backups until manual verification is complete; the importer does not merge existing Kaigi notes.

Preserved identifiers: `Meetrail.MeetingSeries`, `Meetrail.MeetingNote`, `Meetrail.NoteRevision`, every stored model property, note/series/revision UUIDs, legacy system occurrence/series keys, the SwiftData default store location relative to the sandbox, CloudKit `.none`, `selectedCalendars`, `calendarOnboarding.v1`, `aiEnabled`, and `remindersEnabled`. The old `Meetrail QA` fixture calendar/prefix/manifest remain solely to safely discover/clean workflow fixtures. Pending notifications and login registrations belong to separate app identities and are not moved/canceled automatically.

A standalone probe compiled the **original** repository source from Git and Kaigi's source under module `Meetrail`. Kaigi reopened the original synthetic SwiftData store with identical note/series UUIDs and occurrence key, retained confirmed context, two revisions and disabled carry setting. The owner-mediated helper then exported/imported that real synthetic schema (one series, one note, two revisions), and Kaigi's probe reopened it successfully. Helper tests cover WAL data, preferences including intentionally empty selection, no-overwrite behavior and corrupt-manifest rejection. Real backup stores and probes remain outside Git.

New-identity startup created its own default store with **zero series/notes/revisions**; it did not automatically import an old store. Calendar/notification consent and login setup require renewed attention. No real user store was migrated, reset or deleted.

**Baseline QA incident:** one initial temporary Meetrail launch omitted synthetic arguments before being corrected. No note editing or migration occurred, and the old default.store modification time remained 26 October 2026 at 17:08:25. The old preferences plist was updated at 22:05:01 on 28 October, and no pre-launch preference snapshot exists. Its exact earlier state cannot be claimed or restored safely; this was disclosed during the work. Subsequent before/after runs use synthetic in-memory data. The existing owner-run app was not removed or replaced.

## Tests and runtime validation

Host: macOS **26.6.2 (25G83)**; Xcode **27.0 (27A266a)**.

The first signed Debug and universal Release builds passed. The first full UI pass passed **all 16 UI tests**. All **46 Swift Testing tests** and the real-calendar XCTest passed with complete tracked attendee-free fixtures; the real Clean Up/Structure probes ran on synthetic text. Semantic accuracy of generated text still requires human review. An earlier unit run reached the calendar fixture guard and skipped that test before fixtures were created; later real-calendar execution passed with zero skips.

Two visual refinement passes inspected actual Light/Dark agenda, notes, context/history, AI review, settings, onboarding, connections/selection, empty states, long titles, constrained windows and accessibility text sizes. Pass one centralized palette/button hierarchy and lighter weights. Pass two aligned floating-editor/sidebar backgrounds, regularized metadata weights, integrated the vector mark and refined Mono contrast. The final full suite and build results are recorded below.

The first original-app baseline UI attempt hit a native scroll-view targeting failure. A later contrast rerun also hit an agenda-launch/focus assertion while a duplicate installed synthetic Kaigi process remained running; the duplicate was identified and closed before a clean repeat. A clean synthetic repeat passed in both appearances and produced the before screenshots; the corresponding Kaigi scenario also passed. No assertion was removed or failure converted to a skip.

Launch at login was tested with the **real SMAppService adapter** using synthetic calendars/notes: Off → On → Off with no error. It was restored to Off. A boot-time relaunch from the final installation location has not been observed. The temporary development bundle initially returned **“Notifications are not allowed for this application”**; unified logging also reported failure to validate the notification client. The owner subsequently allowed Kaigi notifications. On 28 October at 23:19:49, macOS logged authorization `allow: YES`, and the installed app logged `didGrant: 1`, `hasError: 0`. Its real Settings checkbox reflected enabled consent. Reminders were returned to Off and the native remove-pending call was observed. Sample mode intentionally suppresses scheduling in the agenda use case, so the synthetic next-day exercise did not submit native reminder requests. Five-minute scheduling/replacement is verified by unit tests; actual notification-banner delivery remains unobserved.

## Manual repository and Apple actions

The owner can rename the existing GitHub repository without changing visibility:

```sh
gh repo rename Kaigi --repo ArtemkaK1/Meetrail --yes
git remote set-url origin https://github.com/ArtemkaK1/Kaigi.git
git remote -v
```

Alternatively use GitHub Settings → General → Repository name, and use `git@github.com:ArtemkaK1/Kaigi.git` for SSH origin. These commands were not run.

Use the existing **Kaigi - Meeting Notes** App Store Connect record. Finish metadata, screenshots, category, age rating, rights, privacy/accessibility and applicable compliance fields. Review any historical remote Xcode Cloud/GitHub publishing jobs before distribution. Check accepted build numbers before an explicitly authorized upload. No marketing version bump, archive upload or TestFlight operation was performed.

## Remaining validation boundaries

Real user-data transfer, boot-time login after installation, live notification delivery, full spoken VoiceOver navigation, system-wide Increase Contrast/Reduce Transparency, every wallpaper/lighting combination, macOS 15 runtime, Intel runtime (universal build only), notarization, App Review and distribution upload require separate observation. External real conference entry was not exercised with placeholder fixture URLs. The separate website repository was not modified.

## Final command evidence

| Check | Result / evidence |
|---|---|
| Signed Debug | PASS; final metadata rebuild in Xcode 27 and additional signed Xcode 26.4.1 build |
| Signed Release | PASS; universal arm64 + x86_64 product, including final contrast and metadata rebuilds |
| Unit and calendar tests | 46 Swift Testing tests + one real-calendar XCTest passed, no failures/skips |
| Full UI tests | PASS: all 16 in the clean final UI run, zero failures/skips; the contended run with two focus failures is retained and documented |
| Architecture | `python3 Tools/verify-architecture.py` PASS |
| Transfer helper | `python3 Tools/test-transfer-data.py` PASS (2 tests), plus real synthetic SwiftData transfer/reopen probe |
| Project | `plutil -lint` PASS; Xcode lists Kaigi/KaigiTests/KaigiUITests, Debug/Release and only Kaigi shared scheme |
| Whitespace | `git diff --check` PASS; new text files also scanned for trailing whitespace |
| Signature | Authorized strict verification PASS; team WX557M9HD2, sandbox/calendar/user-selected-file entitlements retained |

Logs and full result bundles remain outside Git under `/tmp/kaigi-review/`. Final metadata-build logs: `final-format-debug.log`, `final-format-release.log`, `stable-xcode-debug.log`. Final passing UI result bundle: `final-ui-clean.xcresult`. The final 46 unit tests and real-calendar test passed in `final-contrast-tests.xcresult`, whose UI portion had two focus failures while a duplicate QA app was running. The complete clean UI repeat passed all 16 unchanged tests after that process was closed. Prior complete combined passing suite: `final-tests.xcresult`. Temporary build artifacts are not releases or TestFlight uploads.

## Before/after screenshots

All captures use synthetic data. Comparisons crop only the unrelated pixels outside the native popover body; the application pixels are unchanged.

- [Notes Light comparison](Brand/Previews/comparison-notes-light.png) / [Dark comparison](Brand/Previews/comparison-notes-dark.png).
- [History & Context Light comparison](Brand/Previews/comparison-context-light.png) / [Dark comparison](Brand/Previews/comparison-context-dark.png).
- [Agenda Light](Brand/Previews/after-agenda-light.png) / [Dark](Brand/Previews/after-agenda-dark.png).
- [AI review](Brand/Previews/after-ai-review.png), [Settings](Brand/Previews/after-settings.png), [onboarding](Brand/Previews/after-onboarding.png), [calendar selection](Brand/Previews/after-calendar-selection.png), [empty state](Brand/Previews/after-empty.png).
- [Connections Light](Brand/Previews/after-connections-light.png) / [Dark](Brand/Previews/after-connections-dark.png).
- Status-item crops show the real monochrome template under both app appearances; the global menu-bar appearance remained unchanged. Full system Light/Dark menu-bar switching was not performed.

## Installed handoff

The verified universal Release product is installed at `/Users/artemiy/Applications/Kaigi.app`, bundle ID `com.volrik.kaigi`, team `WX557M9HD2`, version 1.0 (1). It replaced only the temporary Kaigi QA installation created during this task, which was moved to an external temporary backup. No Meetrail application was removed/replaced. The installed Release signature passed strict verification.

Tracked calendar fixture cleanup completed successfully, its local manifest was removed, and the QA calendar was retained. Notification permission is allowed by the owner's action; reminders and launch-at-login were left Off after verification. Native reminder banners remain untested because the sample agenda intentionally suppresses scheduled requests.
