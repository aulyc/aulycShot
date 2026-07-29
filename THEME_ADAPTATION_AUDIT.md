# Light theme adaptation audit

## Scope

Included: every custom popup dialog, popover, toolbar, sub-toolbar, and transient HUD outside Settings

Excluded by product requirement:

- Settings window and Settings panes
- Image-content overlays whose fixed contrast is part of the editing result rather than app chrome, such as selection handles, crop masks, QR target markers, and pinned text paper

## Inventory

The audit found 20 custom theme-sensitive surfaces and 8 native AppKit dialog or sheet call sites, for 28 reviewed user-visible entry points

| Group | Surfaces | Count | Adaptation |
| --- | --- | ---: | --- |
| Editor chrome | Primary toolbar, side toolbar, color and size sub-toolbar, mosaic sub-toolbar, text sub-toolbar | 5 | Adaptive backgrounds, borders, icons, separators, sliders, checkboxes, and selected states |
| Scroll capture | Hint, active control, crop confirm control, preview | 4 | Adaptive floating backgrounds and control colors |
| Pin toolbars | Image pin toolbar, text pin toolbar | 2 | Adaptive capsule backgrounds, borders, labels, and icons |
| Custom dialogs | Image Merge window | 1 | Adopted semantic text and surfaces, refreshed layer colors on appearance changes |
| Transient HUDs | Toast, tooltip, cursor chip, update progress, recording HUD | 5 | Adaptive floating surfaces, borders, text, indicators, and live appearance refresh |
| Native AppKit dialogs | 5 `NSAlert` call sites and 3 open or save panel call sites | 8 | Reviewed; these inherit the system appearance after forced-dark parent windows were removed |

## Root causes

- The update progress window explicitly forced `darkAqua`
- Editor and pin toolbars used fixed dark gray fills plus white icons and separators
- Several layer-backed controls converted semantic `NSColor` values to `CGColor` only once, so they could become stale after a live system appearance change

## Implementation contract

- `AdaptiveChrome` owns the semantic floating, toolbar, panel, popover, card, border, separator, and selected-state colors
- Custom drawing reads dynamic AppKit colors at draw time
- Layer-backed reusable surfaces resolve their colors against `effectiveAppearance` and reapply them from `viewDidChangeEffectiveAppearance`
- Accent-green selected states retain white foregrounds for contrast in both appearances
- Image content and QR code rendering remain color-stable and are not tinted by the app theme
