Meetrail Carryline app icon

Approved direction: A2, 25 October 2026. See design-approval.yaml.
Original concept was created with built-in image_gen from this project's brief; no third-party artwork was used. The generated symbol is reconstructed deliberately in 01-carryline.svg, rather than auto-traced. Colors are medians sampled from the approved A2 rendering, preserving its warm orange/ivory appearance while removing incidental generation noise.

01-carryline.svg is an unmasked full 1024px transparent source. Background and final platform mask belong to Icon Composer. The foreground should remain opaque with material effects disabled to preserve the approved flat design.

The shipping source is Meetrail/AppIcon.icon, created, edited and saved in Apple Icon Composer 27.0. It contains the native solid orange canvas and one opaque foreground SVG in one group. Foreground glass effects are disabled. macOS is the only enabled platform. The package's icon.json is owned by Composer and was not hand-authored.

The existing Xcode synchronized Meetrail group includes AppIcon.icon automatically. The app's existing AppIcon build setting selects it. The legacy Tools/GenerateIcon.swift and existing AppIcon.appiconset are preserved; Xcode uses the Composer document in preference to the same-named catalog. Do not run that historical generator to produce Carryline.

Validated on macOS 26.6.2 with Xcode 27.0: signed Debug/Release builds; 42 reported deterministic unit tests across four suites; two focused GUI tests; actual compiled fallback artwork at 256/32/16 pixels; Finder Get Info for the signed Release app; Composer Default/Dark/Mono previews. No application Swift code, status item icon, schema, permissions or dependency settings changed.

Remaining: Clear/Tinted light/dark Composer previews, varied photographic wallpapers/lighting angles, macOS 15 runtime, distribution signing/notarization and store delivery. Static review files and screenshots remain outside Git in this session's meetrail-icon-exploration/a2-production-proof directory. See Docs/VALIDATION.md for commands, logs and scope.

Apple route documentation: https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer
