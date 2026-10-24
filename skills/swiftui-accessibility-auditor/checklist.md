# SwiftUI accessibility audit — P7–P11

Scope: native macOS feature Views and shared components. The deployment target remains macOS 15. No iOS touch-target assumptions were applied to native Mac controls.

## P0

No source-level blocker found. This is not certification of complete assistive-technology behavior.

## P1 — fixed

- Provider cards were merged into one accessibility text element, which hid individual provider boundaries. Each card now contains its own children in `CalendarAccountsView.swift`:
  ```swift
  .accessibilityElement(children: .contain)
  .accessibilityIdentifier("provider-card-\(card.kind.rawValue)")
  ```
  The UI test finds five separate Coming Soon statuses and one real system connection. Native macOS static text exposes content through `value`, so assertions inspect `value` as well as `label`.
- Fixed arbitrary feature font sizes and per-view colors. `AppTextModifier` uses scaled system roles and semantic AppColors. A real UI test opens notes with accessibility-size text inside a constrained 480-point presentation. It verifies accessible date navigation, separate Join, and the notes editor.
- Icon-only buttons have concrete accessible names through `SymbolButton`:
  ```swift
  .accessibilityLabel(label).help(label)
  ```
  Card and Join remain separate native Buttons. The card value includes time, calendar, provider, note and prior-context status, so state is conveyed beyond color.

## P2 — reviewed

- Weekday, note title, selection title and onboarding titles expose header traits.
- Checkboxes expose calendar names and checked state; decorative calendar-color dots are hidden from accessibility. Per-account All/None buttons name their account.
- Standard TextEditor preserves text navigation, selection, undo and redo. Manual real-calendar long-note editing and undo/redo were verified.
- No authored animation or motion-only interaction requires a Reduce Motion alternate. System control animations follow macOS preferences. No custom gesture is required to activate a core action.
- Native semantic backgrounds/text support light/dark, contrast and transparency preferences. Coming Soon uses readable secondary text rather than tertiary disabled text.

## Manual verification still required

1. With VoiceOver enabled, move through a synthetic agenda using Control-Option-Right; expect date/header, each meeting's title/time/provider/state, then its independent Join action.
2. In onboarding and Accounts & Calendars, expect six distinct provider groups, five honest Coming Soon states, source disclosure controls, per-source selection actions and named checked/unchecked calendars.
3. Enable Keyboard Navigation in macOS Keyboard settings; Tab/Shift-Tab must reach all native buttons and checkboxes. Command-left/right and Command-T navigate the agenda. Command-[ returns from notes. Escape dismisses the agenda or cancels an AI review.
4. Check long text with macOS larger text, Increase Contrast, Reduce Transparency and Reduce Motion. Expect scrolling without clipped essential controls. The synthetic scaled-text fixture does not replace a test on multiple physical displays.
5. With Voice Control, activate a meeting, its Join action and a named calendar checkbox. The visible names and accessible labels should identify the intended action. Full spoken-output/Voice Control operation has not been reported as passed.

Regression risk: scaled text increases height and wrapping; the panel clamps to available screen height and retains scrolling. Native keyboard focus follows the user's Keyboard Navigation preference. Provider grouping changes accessibility structure without changing connection or calendar-selection behavior.

P11: compact chevrons and toolbar symbols retain explicit accessible names. The empty editor has a visible placeholder and a separate accessible label/hint. AI review exposes a heading plus native Apply/Cancel buttons; Settings exposes the AI checkbox. Decorative borders ignore hit testing. Automated typing/focus and right-click Settings/Quit checks cover the borderless panel. Full spoken VoiceOver output remains a manual check.
