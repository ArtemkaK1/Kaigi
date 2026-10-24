# Local QA and manual product review

All fixture titles start with `[Meetrail QA]`. The standalone Tools/CalendarQA.swift program is not included by the synchronized Meetrail/ source group. Never move it into production sources. It creates a dedicated calendar, seven attendee-free fixture groups, finite daily/weekly recurrences and a moved exception. It records calendar and event identifiers only in `/tmp/meetrail-qa-manifest.json`. Do not commit that file. Placeholder URLs test parsing/opening only. Never claim they enter a conference.

From the repository root run `Tools/run-calendar-qa.sh` to compile and open the standalone fixture app. Run `Tools/run-calendar-qa.sh --cleanup` after testing. Allow the system calendar prompt for this separate QA app. Do not run setup concurrently. For an own-account test link, pass it only as a local runtime argument: `Tools/run-calendar-qa.sh --own-link 'YOUR_OWN_MEET_HTTPS_URL'`; never put it in source or commit it.

The workflow builds a temporary app bundle `/tmp/MeetrailCalendarQA.app` with an EventKit usage description and the compiled QA executable. Relaunch that app with `open -n /tmp/MeetrailCalendarQA.app --args --cleanup` to remove only manifest-listed fixtures. Do not delete the whole calendar. Retain the manifest until cleanup succeeds. If the machine reboots and /tmp is cleared, inspect the dedicated calendar manually; delete only this workflow's synthetic events, never personal/work events.

Manual checklist (items count as passed only when recorded in VALIDATION.md):

1. Launch the real app. Click its note menu-bar icon twice to verify open/dismiss; click outside and Escape. Verify Today reset on each fresh opening, panel width and scrolling.
2. Connect calendars. Approve macOS's Full Access prompt; production has no writing methods. Confirm the dedicated QA calendar is selected. Check Today, tomorrow, and two days later. Verify chronological order, all-day, overlapping, daily, weekly, moved exception, no-link and all four provider fixtures. Compare to Calendar.app.
3. Create/edit notes on a QA event. Close/reopen the popover and quit/relaunch the app. Confirm the exact text survives. Open Float notes, switch to another app, type/edit, and confirm both editors share saved content. Restore a revision and export Markdown to a selected folder.
4. On an earlier recurring QA occurrence, enter and confirm only synthetic decisions/questions. Open the next occurrence and review/carry the text. Check separate occurrence drafts. Turn off previous-context display for the series. Confirm it remains off after relaunch.
5. Modify/cancel only fixtures tracked by this workflow, using Calendar or the separate QA harness. Confirm updates arrive without polling. Verify the affected meeting remains accessible as Calendar history on its original agenda day and through related meeting history. Test a calendar resync in a disposable calendar: changed external identities must stay separate.
6. Click Join on a placeholder and verify only URL handoff. It is not a real call. To verify conference entry, supply a genuine link belonging to your own account, with no invitees; no such link is fabricated or inferred.
7. Check AI status. If enabled and ready, use synthetic rough notes with uncertainty, names/numbers, tentative deadlines and explicit non-decisions. Review Clean Up and Structure previews, Cancel, Apply, then restore the original revision. Change notes while a preview is pending and verify stale apply is rejected. Use an unsupported language and confirm a clear error with no text changes. No cloud fallback.
8. In Settings enable reminders, approve the OS prompt, and create/move a workflow-owned fixture to 6 minutes ahead. Confirm the five-minutes-before notification contains no private title/text; disable reminders. Validate notification denial in System Settings and restart. Enable/disable Launch at login from an installed, appropriately signed copy; verify macOS Login Items.
9. Tab/Shift-Tab through all controls; Command-left/right and Command-T; Command-[ back and Escape dismiss/cancel. Use VoiceOver for card vs Join labels, calendar toggles, text editor and export controls. Test Large Text/contrast, light and dark appearance, Reduce Motion, long titles, many meetings, empty days, permission denial/revocation and no calendars.
10. Build Release, run the full unit/UI suite, inspect memory/CPU over a working day, validate macOS 15 on an actual supported system, and resolve certificate/notarization before distribution. Audit working tree and every Git history blob again before any explicitly authorized public push.

## P6–P10 stabilization regression

The current structure and dependency rules are in [AGENTS.md](../AGENTS.md). The previous P0–P5 checklist above is historical; current completed checks and remaining work are recorded in the stabilization section of [VALIDATION.md](VALIDATION.md).

Use normal automatic signing now that the existing development certificate is available. The core target stays macOS 15; Foundation Models are optional on macOS 26+. No certificate creation, revocation, OAuth or external synchronization work is needed for this regression.

```sh
xcodebuild -project Meetrail.xcodeproj -scheme Meetrail -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/MeetrailReview build
xcodebuild -project Meetrail.xcodeproj -scheme Meetrail -configuration Release \
  -destination 'platform=macOS' -derivedDataPath /tmp/MeetrailReview build
Tools/run-calendar-qa.sh
xcodebuild -project Meetrail.xcodeproj -scheme Meetrail -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/MeetrailReview \
  -parallel-testing-enabled NO test
python3 Tools/verify-architecture.py
git diff --check
Tools/run-calendar-qa.sh --cleanup
```

Select ABC as the input source for XCTest's Latin `typeText` operations. Russian input caused the baseline event synthesizer to time out; direct typing was functional. Restore your preferred input source afterward. Let XCTest own the foreground while it runs. Native agenda panels intentionally dismiss on deactivation; interacting with other apps or OS prompts can interrupt GUI tests. Tests explicitly activate the app and treat the borderless agenda as a window, while floating notes and onboarding are native windows. No behavior assertions were removed and no failures were converted to skips.

The calendar integration test requests permission only for its real test host. An isolated/ad-hoc host may need its own approval even when the normally signed app already has access. Keep this test intact; a permission skip is not a pass. Use a stable signed build and approve the named host's macOS prompt. The final normally signed run in VALIDATION.md completed this test without a skip.

### Synthetic layouts and onboarding

```sh
open -n /tmp/MeetrailReview/Build/Products/Debug/Meetrail.app --args --sample --show-agenda
open -n /tmp/MeetrailReview/Build/Products/Debug/Meetrail.app --args --sample --empty --show-agenda
open -n /tmp/MeetrailReview/Build/Products/Debug/Meetrail.app --args --sample --fifteen-meetings --long-titles --show-agenda
open -n /tmp/MeetrailReview/Build/Products/Debug/Meetrail.app --args --sample --onboarding --fifty-calendars
open -n /tmp/MeetrailReview/Build/Products/Debug/Meetrail.app --args --sample --large-text --constrained-height --fifteen-meetings --show-agenda
```

Quit the previous review instance before starting another. Debug fixtures are deterministic and attendee-free, and do not require calendar access. Sample notes are in memory. `--test-session UNIQUE_ID` retains synthetic onboarding/selection preferences across relaunch; use a new ID for a clean first run. These flags are excluded from Release composition. A synthetic constrained-height preview is not a claim of testing another physical display.

1. First run: expect Welcome in a separate window with no automatic calendar prompt. Continue; expect six provider cards, only the system provider connectable and five Coming Soon states. Connecting system calendars is the only permission trigger. Existing synchronized calendars may appear, but direct provider authentication is not implemented.
2. Selection: connect the synthetic system provider and expect 50 calendars across five account groups. Expand/collapse an account. Deselect/Select All should change the total by 10. Search Calendar 42; expect one calendar and its account. An individual checkbox changes total by one. Group actions during search still act on the full account.
3. Skip/relaunch: preserve onboarding disposition/stage. Complete setup; no forced setup on next launch. Settings → Accounts & Calendars opens the shared connection/selection screens.
4. Existing data: retain the original store and `selectedCalendars` preference. Existing notes or calendar selections classify a returning user without resetting data. An empty selected set remains empty. Missing/revoked calendars retain their IDs; renaming a source/calendar does not select unrelated IDs.
5. Data safety: simulate a repository write failure with the injected test store. The editor must retain the draft, retry must recover, quit must retry/offer to stay open on failure, and Markdown export must contain the current draft even if persistence failed. AI previews must not change stored notes until applied; stale previews must be rejected. Floating and agenda editors share the same ViewModel.
6. Provider extension contract: only test fixtures implement alternate providers in tests. Register an adapter through the composition root; descriptors and namespaced identities flow through the same visibility, selection and note use cases. Do not deduplicate different-provider events by title or assume synchronized copies are the same occurrence.

See the [accessibility audit](../skills/swiftui-accessibility-auditor/checklist.md) for VoiceOver, keyboard-navigation and contrast review. Remaining manual checks include full spoken output, physical display variations, notification banner delivery, login-at-login after restarting an installed app, permission revocation/reapproval, provider-wide resynchronization, macOS 15 execution and extended performance/durability measurement. None are implied by a successful build or deterministic mock test.

## P11 focused UI regression

- Left-click the status icon to open/dismiss. Right-click it for Settings… and Quit Meetrail. Command-comma uses the same native Settings scene. No Quit, Saved Notes or repeated Back controls should appear inside the panel.
- Compare synthetic before/after captures linked in VALIDATION.md. Verify 0/1/15 meetings, long titles, separate card/Join actions, light/dark, scaled text and bounded scrolling. With one meeting, the panel ends immediately below the card rather than retaining a footer/titlebar region.
- In notes, verify the empty placeholder, visible editor boundary, Command-[ back, pin/export and Meeting history. Context for next time → Edit → Confirm context remains explicit; previous confirmed context and Carry into notes remain available. After removing only a tracked QA event, use its original agenda date's Calendar history card to recover the note. Related occurrences are accessible only through Meeting history.
- Settings → On-device AI controls refinement. With `--sample --show-agenda --mock-ai`, Clean Up/Structure return a deterministic suggestion: Review changes must leave the editor unchanged; Cancel discards it; Apply creates a revision. This fixture does not validate real inference. Turning AI off disables actions and clears any pending suggestion without changing notes.
- Reminders use a five-minute lead. Preserve the existing enabled/disabled preference. Repeated scheduling replaces pending requests; disabling clears them. Deterministic notification-client tests verify the actual trigger interval and replacement behavior. Banner presentation remains a separate OS-level check.
- Onboarding retains its four stages, permission trigger and persisted skip/completion behavior with content heights of 320 points for Welcome, 440 for connections/selection and 256 for Ready (560 points wide). Connections / Visible calendars has no visible Section label. Five future providers remain Coming Soon. Existing selections and notes must survive relaunch.

## P12 final native design review

- In onboarding and Accounts & Calendars, compare disconnected, connected and Coming Soon cards. Each card uses the same two-column grid: provider/status icons share an axis; name/status text share a leading edge. Long Microsoft names must wrap above their status. Inspect both appearances and `--large-text`; scroll to remaining providers when needed. The debug enlarged-text fixture also applies to these windows.
- At enlarged text sizes, Welcome and Ready content must wrap and scroll without hiding the footer actions. Normal-size content remains centered within the existing compact window dimensions.
- With `--sample --show-agenda --mock-ai`, enter a synthetic note, request Clean Up, change the note, then Apply the old preview. Expect the existing stale-preview error, unchanged edited text, Saved locally and Dismiss. Retry save belongs only to an unsaved state. Cancel still discards the preview. The mock does not validate real inference.
- Return activates onboarding's default action. Existing Command-comma, Command-[, day-navigation and Escape shortcuts remain covered by GUI tests. Review full Tab/Shift-Tab traversal with macOS Keyboard navigation enabled, and verify spoken VoiceOver output manually; an accessible element tree alone does not prove spoken behavior.
- No decorative motion was added. Keep the existing immediate pressed feedback, native scrolling, orange accent and reduced-motion behavior. Use synthetic captures linked in VALIDATION.md; do not save real calendar/account data in repository screenshots.
