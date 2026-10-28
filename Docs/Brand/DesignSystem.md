# Kaigi design system

Kaigi (会議) is calm, minimal and native to macOS. The identity anchor is the owner's sketch: a small oval above a tall tapered body with a rounded base. No calendar, notebook or generic K is substituted. The tagline remains **Your meetings. Your notes. All connected.**

## Semantic colors

All values are sRGB. `AppColors` resolves Light/Dark appearances through adaptive NSColor tokens; feature views never author literal colors. The AccentColor asset matches the semantic accent. Explicit tint at every app/window root keeps native controls in the purple family even when the user chooses another system accent. The native popover/window shell keeps macOS material; content uses deliberate opaque neutral surfaces.

| Token | Light | Dark |
|---|---|---|
| Background / popover | `#F7F7FA` | `#1C1A20` |
| Surface / editor | `#FFFFFF` | `#27242D` |
| Elevated surface | `#FFFFFF` | `#302B37` |
| Primary text | `#211E27` | `#F4F1F8` |
| Secondary text | `#66616F` | `#B6B0C0` |
| Disabled text | `#807A89` | `#938B9F` |
| Accent | `#713BD1` | `#BE9AF6` |
| Primary fill | `#713BD1` | `#8146CC` |
| Primary hover | `#6430BF` | `#8B50D7` |
| Primary pressed | `#5727AA` | `#7138B9` |
| Accent foreground | `#FFFFFF` | `#FFFFFF` |
| Selection | `#EDE5FA` | `#3B2D51` |
| Secondary control | `#E9E6EF` | `#3A3444` |
| Secondary hover | `#DFDAE9` | `#484052` |
| Secondary pressed | `#D4CCE2` | `#53485F` |
| Disabled control | `#EEECF2` | `#302B37` |
| Border / separator | `#D9D5E1` | `#4C4557` |
| Error | `#B32636` | `#FF929C` |
| Warning | `#865500` | `#E9BD6C` |

Calculated contrast: primary text/background 15.35:1 Light and 15.42:1 Dark; secondary text/surface 5.99:1 and 7.24:1; white/primary fill 6.46:1 and 5.70:1. Warning/error/accent text on the background each exceed 5.9:1. Disabled states intentionally use reduced emphasis. Calendar colors represent account data and retain their provider colors; they are not brand accents.

## Controls

Use the single `KaigiButtonStyle` with a semantic level:

- **Primary:** purple fill and white label. Join/Links, Continue, Apply, Confirm context and connection completion actions.
- **Secondary:** a neutral fill clearly darker/lighter than its surface, with neutral text. AI tools, account selection and supporting actions. No decorative stroke.
- **Tertiary:** neutral text/icon without a resting background or border. Navigation, Today, Back, Export, Float, Revisions and History & Context.

Hover and pressed states use separate semantic fills. Disabled states are neutral. Keyboard focus is retained and a focused shared button receives a purple ring; labels/help remain explicit for icon actions. No focusability is removed and no duplicate button framework is introduced. Native menus, segmented pickers, checkboxes and text fields retain their behavior. Editor/text-field borders remain functional. Shared icon controls are at least 24×24 pt; text and conference actions at least 32 pt high, conference width 64 pt, scaling with text. The agenda remains keyboard and accessibility operable.

## Typography and layout

Use San Francisco via `.system`, authored through `.appText`. Four scaled roles: caption **11**, body **13**, section **16**, title **20**. Semibold is reserved for titles/headings. Medium marks meeting names, provider/account headings, selected states and button actions. Body copy, dates, times, metadata, messages and explanations use regular. Button labels use the shared **13 pt medium** role. Native controls retain platform text behavior. No custom fonts or new role sizes.

All stack spacing/padding uses AppSpacing: **0/8/16/24/32/40/48**. Borders, radii and control dimensions are documented geometry, separate from layout spacing. The 344 pt day agenda sizes from rendered content with a bounded scroll viewport; there is no row-count height estimate or hidden titlebar spacer. Notes remain scoped to occurrences and meeting history.

## Icon review and production

Concepts are versioned under `Concepts/`. The PDF supplied by the owner is the primary identity reference and is not redistributed in the repository. A1 was the flat geometry exploration. A2 added depth and `#F5F5F5`; the owner selected A3 with the broad rounded top cap and straight flanks. A4’s gloss was rejected. A3 was reconstructed as exact SVG arcs/lines with smooth matte radial color fields and a native Composer shadow. Production approval, source geometry, platform appearance evidence and integration status are recorded with the app-icon sources.

The icon background is independently specified; it does not replace every application surface token. A monochrome template symbol is used in the status bar so macOS controls its Light/Dark appearance. Full-color app artwork is not used as the status item.
