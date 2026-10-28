# Kaigi A3 app icon

The owner approved A3 on 28 October 2026, then requested clean vector edges. A4's gloss was rejected. The supplied PDF is the identity anchor and is not redistributed.

`Kaigi-symbol-master.svg` and `01-symbol-matte.svg` are editable vector artwork with exact circular caps and straight tangent sides. Two broad radial color fields express the intrinsic matte violet surface; there is no raster tracing, filter, bevel, narrow specular strip or baked drop shadow. `01-symbol.svg` is the flat-color master and `Kaigi-symbol-monochrome.svg` is the status/template master. The slender footprint is intentional and preserves the approved sketch, rather than following a generic square-logo footprint score.

The shipping source is `Kaigi/Kaigi.icon`, created and saved in Apple Icon Composer bundled with Xcode 27. Only macOS is enabled. It contains one group and one SVG layer, native #F5F5F5 sRGB canvas, native neutral shadow at 50%, specular off, refraction/blur off and translucency off. Mono uses System Light fill for recognition. The SVG retains the matte surface color fields because the approved frontal shaded form requires per-shape radial illumination; Composer owns platform masking, backdrop, shadow and appearance adaptation. The package JSON was not hand-authored.

The target's App Icon name is `Kaigi`. The matching `Kaigi.appiconset` contains updated fallback PNG wells derived from the native Default export. Xcode uses the matching Composer source and generates earlier-release fallback representations. Native macOS exports retain the system mask and transparent corners; they are not opaque iOS marketing masters. The generic skill preflight incorrectly flags this native macOS transparency under its flattened/iOS alpha rule. SVG audits and actual Xcode/runtime checks are recorded separately; that flag was not hidden or changed into a pass.

`Exports/Kaigi-macOS-Default-1024@1x.png` is the high-resolution native source export. `Exports/Kaigi Exports/` contains all six actual Composer exports (Default, Dark, Clear Light/Dark, Tinted Light/Dark). The 16/32/64/128/256/512/1024 PNGs form the size ladder. Exports include an sRGB profile without altering their pixels. Previews are in `Docs/Brand/Previews/`; the six-appearance board uses actual Composer exports, not simulated tints.

`KaigiStatus.imageset` uses the independent monochrome vector with template rendering; status items set `isTemplate = true`. The full-color icon is never used in the menu bar.

Validated on macOS 26.6.2: vector curves, small sizes, Composer Default/Dark/Mono, six native appearance exports, Xcode build selection and actual native About panel. Older macOS runtime, every photographic wallpaper/lighting angle, distribution/App Review and notarization remain untested. This is original artwork derived from the owner's sketch; it does not establish trademark clearance.

References: [Apple Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer), [app icon specifications](https://developer.apple.com/design/human-interface-guidelines/app-icons/).
