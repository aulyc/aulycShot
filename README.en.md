<p align="center">
  <img src="images/app-banner.png" alt="aulycShot app banner" width="760" />
</p>

<h1 align="center">aulycShot</h1>

<p align="center">
  The fastest menu bar screenshot tool for macOS: double-tap <code>⌘</code> to capture, annotate, and pin.
</p>

<p align="center">
  <a href="https://github.com/aulyc/aulycShot/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/aulyc/aulycShot?style=flat-square"></a>
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-black?style=flat-square&logo=apple">
  <img alt="Swift 5.9" src="https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-lightgrey?style=flat-square"></a>
</p>

<p align="center">
  <a href="README.md">简体中文</a> ·
  <a href="README.en.md">English</a> ·
  <a href="README.fr.md">Français</a>
</p>

<p align="center">
  <a href="https://github.com/aulyc/aulycShot/releases/latest">Download</a> ·
  <a href="CHANGELOG.md">Changelog</a> ·
  <a href="https://github.com/aulyc/aulycShot/issues">Issues</a>
</p>

**The fastest way to grab, mark up, and share screenshots on macOS.** Double-tap `⌘` from anywhere, snap to a window or drag a region, then annotate in one tight floating window. Lives in your menu bar. No Dock icon, no telemetry, no subscription, no third-party dependencies.

<p align="center">
  <img src="images/editor.png" alt="aulycShot annotation editor — arrows, numbered callouts, mosaic, highlighter and text layered on a screenshot in a single floating toolbar" width="760" />
</p>

<p align="center">
  <a href="https://github.com/aulyc/aulycShot/releases/latest"><b>Download Latest Release</b></a> &nbsp;·&nbsp;
  macOS 14+ &nbsp;·&nbsp; Apple Silicon (arm64)
</p>

## Why aulycShot

- **One shortcut, zero friction.** Double-tap `⌘` anywhere and aulycShot is on screen in milliseconds — or record any global hotkey you like.
- **Snap-to-window or pixel-perfect region.** Hover any window for a one-click capture, or drag a region with full Retina output across every connected display.
- **A real annotation editor.** Arrows, numbered callouts, text, mosaic, highlighter, pen — all editable, draggable, rotatable and undoable *after* you place them.
- **Pin screenshots.** Keep the final image floating above any window as a ready reference.
- **Edit Finder images too.** Select a single image file in Finder and trigger the same shortcut to load it straight into the editor — the original is never touched.
- **Built with pure AppKit.** No SwiftUI, no Electron, no telemetry. Small, fast, and respectful of macOS.

## Showcase

<table>
<tr>
  <td width="100%" align="center">
    <img src="images/window-snap.png" alt="Smart window detection — green dashed bounds snap to an app window" /><br/>
    <sub><b>Snap to any window in one click</b><br/>No precise dragging — aulycShot detects window bounds for you.</sub>
  </td>
</tr>
</table>

## Features

- **Edit any image directly** — select a single image file in Finder (Desktop or any window) and trigger the screenshot shortcut to open that image in the annotation editor instead of taking a screenshot. The original file is never modified; the edited result goes to the clipboard like a normal capture.
- **Smart selection and free-form capture** — hover accessible controls, icons, or windows; press `Tab` to cycle through element, window, and current-screen bounds; or drag any custom area.
- **Multi-display support** — creates overlays on every connected screen and captures at full Retina resolution.
- **Full annotation editor** — rectangle, ellipse, arrow, pen, highlighter, mosaic, numbered callouts, and text.
- **Editable annotations** — move existing marks, change color and size, rotate supported annotations, bend arrows/callouts, edit text, delete marks, and use undo/redo.
- **Pin to screen** — float the current screenshot above other windows as a draggable reference image.
- **Save or copy** — save as PNG, confirm to copy PNG/TIFF data to the clipboard, or cancel without output.
- **Custom trigger** — use the default double-tap `⌘`, or record a custom global shortcut in Settings.
- **Settings and localization** — UI in Simplified Chinese and English, plus menu bar icon toggle, launch at login, demo mode, permission status, and shortcut recording.
- **Menu bar app** — runs as an agent app without a Dock icon.

## Requirements

- macOS 14.0+
- Accessibility permission, used for the default double-tap `⌘` trigger
- Screen Recording permission, used by ScreenCaptureKit and screenshot capture
- Automation permission for Finder, requested on first use of the "edit selected image" shortcut

On first launch, aulycShot opens a setup window with one unified Feature Status. It becomes available only when both Accessibility and Screen & System Audio Recording access are enabled; otherwise screenshot and recording actions stop and show the combined permission guide.

## macOS Verification Warning

If macOS shows a warning like `Apple cannot verify "aulycShot" is free of malware`, remove the quarantine flag from the app bundle you trust, then open it again:

```bash
xattr -dr com.apple.quarantine /Applications/aulycShot.app
```

If you are running a locally built copy instead of the app in `/Applications`, replace the path with your actual app location, for example:

```bash
xattr -dr com.apple.quarantine ./.cache/build/aulycShot.app
```

Only do this for builds downloaded from this repository or ones you built yourself.

## Build from Source

```bash
# Build and bundle .cache/build/aulycShot.app
./scripts/bundle.sh
```

For local development, this script rebuilds the app, kills any running instance, launches the new bundle, and verifies that it started:

```bash
bash scripts/rebuild-and-open.sh
```

To package a draggable DMG:

```bash
scripts/package-dmg.sh
```

The app bundle is output to the hidden path `.cache/build/aulycShot.app`; DMGs are output to `dist/`.

## Usage

1. Double-tap `⌘ Command`, press your custom shortcut, or choose **Take Screenshot** from the menu bar.
2. Hover a window and click to capture it, or drag to select any region.
3. Use the floating toolbar to annotate, save, pin, cancel, or confirm.
4. Click the green checkmark or press `Enter` to copy the final image to the clipboard. Press `Esc` or click `x` to cancel.

To edit an existing image instead of taking a screenshot, click a single image file in Finder (so it's the current Finder selection), then trigger the same shortcut. aulycShot copies the file into a temporary working location and opens it in the editor with the toolbar already up. If anything other than exactly one image is selected, the shortcut behaves as a normal screenshot trigger.

## Editor Tools

| Tool | What it does |
|------|--------------|
| Rectangle / Ellipse | Draw outlined shapes with selectable colors and stroke widths |
| Arrow | Draw straight arrows; select an arrow later to move endpoints or bend the shaft |
| Pen | Draw smoothed freehand strokes |
| Highlighter | Draw semi-transparent marker strokes without darkening overlaps |
| Mosaic | Brush pixelated regions over sensitive content, with adjustable block size |
| Numbered | Add incrementing callout badges; drag while placing to add an arrow |
| Text | Add editable single-line text with color and 10-100 pt size controls |
| Undo / Redo | Revert and restore editor changes |
| Move Selection | Drag the whole selected screenshot region after selection |
| Save | Save the current result as a PNG |
| Pin | Keep the current result floating above other windows |
| Confirm | Copy the final result to the clipboard |

When an annotation is selected, aulycShot shows adjustment handles where supported: rotation for shapes, strokes, and text; curve handles for arrows and numbered callouts; endpoint handles for arrows; and edit/delete actions for text and selected annotations.

## Settings

Open Settings from the menu bar to configure:

- Language: Simplified Chinese or English
- Menu bar icon visibility
- Launch at login
- Demo Mode, which allows external screen recorders to capture aulycShot's overlay and editor
- Screenshot shortcut: keep double-tap `⌘`, record a custom shortcut, or restore the default
- Unified Feature Status with Accessibility and Screen Recording permission shortcuts

## Project Structure

- `aulycShot/App/` — app entry point, delegate, and bundle metadata
- `aulycShot/Capture/` — overlay, selection, window detection, ScreenCaptureKit capture, and clipboard
- `aulycShot/Editor/` — annotation models, editor canvas, floating toolbar, mosaic, and pin windows
- `aulycShot/Trigger/` — double-tap `⌘` monitor and custom Carbon hotkey registration
- `aulycShot/UI/` — menu bar controller, toast, cursor chip, and tooltips
- `aulycShot/Settings/` — startup/settings window and preferences UI
- `aulycShot/Utilities/` — defaults, localization, and launch-at-login support
- `scripts/` — compile check, bundle, rebuild/open, icon, and DMG helpers

## Development

```bash
# Fast compile validation for Swift-affecting changes
bash scripts/compile-check.sh

# Build, restart, and verify the local app
bash scripts/rebuild-and-open.sh
```

## Acknowledgments

1. Thanks to the remarkable age of AI for helping more ideas become reality faster;
2. A tribute to Codex and Claude for their continued partnership in creation and development;
3. Thanks to the open-source [capcap](https://github.com/realskyrin/capcap) project for providing the original inspiration and foundation for aulycShot;
4. Thanks to everyone who submits requests, reports issues, and suggests improvements;
5. Thanks to the open-source community and developer tools for inspiration and support;
6. Thanks to aulyc for the persistence and inspiration behind this journey.

## Third-Party Licenses

- [PermissionFlow](https://github.com/jaywcjlove/PermissionFlow) is licensed under the MIT License. See [ThirdParty/PermissionFlow/LICENSE](ThirdParty/PermissionFlow/LICENSE).

## Star History

[View aulycShot Star History](https://www.star-history.com/?repos=aulyc%2FaulycShot&type=date&legend=top-left)

## License

[MIT](LICENSE) · [Third-party notices](THIRD_PARTY_NOTICES.md)
