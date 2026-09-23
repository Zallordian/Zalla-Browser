# Zalla icon kit

The approved original is preserved at `docs/branding/zalla-logo-v1.png`. The icon artwork develops its coral/crimson ribbon Z on charcoal. Artwork was created with the built-in ImageGen tool; exact prompts are in `generation-prompts.json`. Original generated masters are in `source/`.

## Included assets

| Asset | Location | Use |
| --- | --- | --- |
| App Store master | `exports/zalla-app-store-1024.png` | 1024 × 1024 opaque RGB PNG; same design as the default app icon |
| Default appearance | `exports/zalla-default-1024.png` | Standard home screen and system icon |
| Dark appearance | `exports/zalla-dark-1024.png` | Deeper background and brighter ribbon folds |
| Tinted appearance | `exports/zalla-tinted-1024.png` | Neutral silver/gray artwork for system tinting |
| Transparent brand mark | `exports/zalla-mark-transparent-1024.png` | In-app branding and a foreground source for Icon Composer |
| Home screen | `iphone/zalla-homescreen-60pt-2x.png`, `iphone/zalla-homescreen-60pt-3x.png` | 120 and 180 pixels |
| Spotlight | `iphone/zalla-spotlight-40pt-2x.png`, `iphone/zalla-spotlight-40pt-3x.png` | 80 and 120 pixels |
| Settings | `iphone/zalla-settings-29pt-2x.png`, `iphone/zalla-settings-29pt-3x.png` | 58 and 87 pixels |
| Notifications | `iphone/zalla-notification-20pt-2x.png`, `iphone/zalla-notification-20pt-3x.png` | 40 and 60 pixels; supplied for development, does not add notification functionality |

`preview.png` shows the variants and small-size checks. Production app icons remain square with full backgrounds; the operating system supplies the outer shape.

## Project integration

`Zalla/Assets.xcassets/AppIcon.appiconset` contains the default, dark and tinted 1024-pixel masters and their appearance metadata. `project.yml` selects `AppIcon` as the app icon. The existing `sources: [Zalla]` includes the asset catalog. Xcode generates the required device sizes from these masters; the separate `iphone/` files are convenient manual exports, not duplicate catalog entries.

`Zalla/Assets.xcassets/ZallaMark.imageset` contains transparent 128, 256 and 384-pixel assets at 1x, 2x and 3x. Use `Image("ZallaMark")` in SwiftUI when an in-app brand mark is needed. No screens have been changed to display it automatically.

Regenerate exports with `./docs/branding/icons/export-icons.ps1` on Windows. It only sizes and encodes the saved source artwork, and rebuilds the catalog metadata. The original approved logo is not overwritten.

## Mac validation and layered icons

The PNG asset catalog is provided for this iPhone project targeting iOS 17 and later. On a Mac, regenerate the Xcode project, build, and check normal, dark and tinted home screen appearances on supported OS versions. Inspect the archive's icon in Organizer before uploading. These files have been checked locally for sizes, PNG encoding, transparency and catalog references; Xcode compilation and App Store validation have not been run on this Windows machine.

For a native layered Liquid Glass icon, import the transparent mark into Icon Composer on a 1024-pixel canvas and add a charcoal background. Scale the mark to match the default master's visual bounds (approximately 60% of the canvas width); the transparent source has tighter margins. Use the supplied default, dark and tinted icons as visual references. Review clear light, clear dark, tinted light and tinted dark appearances in Icon Composer and on-device before adopting the resulting `.icon` file. This kit includes foreground source artwork, not a compiled or verified Icon Composer document. The system's clear/glass treatments should be generated and reviewed there rather than baked into extra PNGs.

The project currently targets iPhone only. iPad, watchOS, macOS and Android icon packages are outside its present target scope.

## Apple references

- [Configuring your app icon using an asset catalog](https://developer.apple.com/documentation/xcode/configuring-your-app-icon)
- [Creating your app icon using Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer)
- [App icon design guidance](https://developer.apple.com/design/human-interface-guidelines/app-icons)

References checked September 21, 2026.
