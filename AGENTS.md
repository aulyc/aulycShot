# aulycShot

macOS menu bar screenshot tool. Pure AppKit, Swift Package Manager, no third-party dependencies.

## Build & Verification

After every code change, run the compile check:

```bash
bash scripts/compile-check.sh
```

For runtime-sensitive UI changes, run the rebuild script too:

```bash
bash scripts/rebuild-and-open.sh
```

This script builds the app bundle, kills any running instance, launches the new build, and confirms it started.

### SwiftPM in restricted sandboxes

- Ordinary host build/test paths remain `bash scripts/compile-check.sh`,
  `swift test`, and `bash scripts/bundle.sh`; preserve SwiftPM's normal sandbox
  and user-level configuration on those paths.
- In Codex `workspace-write` or a similarly restricted executor, use
  `make sandbox-check`, `make sandbox-test`, and `make sandbox-build`.
- `make sandbox-test` preserves the CI convention
  `AULYC_SKIP_WINDOW_SERVER_TESTS=1`; it skips only tests that explicitly
  require an interactive WindowServer session.
- Restricted commands execute the project-owned
  `scripts/swiftpm-sandbox.sh` copy. It keeps `.build/` as the artifact path,
  uses the ignored `.cache/swiftpm/` for module/shared caches, and disables only
  SwiftPM's nested sandbox. Never replace it with a central-repository runtime
  path or broaden the outer sandbox.
- Private registry configuration and security directories remain opt-in through
  `SWIFTPM_SANDBOX_CONFIG_PATH` and `SWIFTPM_SANDBOX_SECURITY_PATH`; never store
  credentials in the repository or `.cache/swiftpm/`.

## Project Structure

- `aulycShot/App/` — Entry point (`main.swift`, `AppDelegate.swift`, `Info.plist`)
- `aulycShot/Capture/` — Screen capture logic (ScreenCaptureKit, selection overlay)
- `aulycShot/Editor/` — Post-capture annotation editor
- `aulycShot/Trigger/` — Double-tap ⌘ key detection
- `aulycShot/UI/` — Status bar, toast, cursor chip
- `aulycShot/Settings/` — Settings dialog (startup + preferences)
- `aulycShot/Utilities/` — UserDefaults wrapper
- `scripts/` — Build and bundle scripts

## Key Rules

- **Always run `bash scripts/compile-check.sh` after modifying code** to verify the compile.
- No SwiftUI — this project uses AppKit exclusively with programmatic UI.
- No storyboards or XIBs.
- Minimum deployment target: macOS 14.0.
- All newly added user-facing copy must not end with punctuation. Punctuation
  inside the sentence is fine, but the final character of every visible string,
  tooltip, alert, toast, menu item, placeholder, and localized value must not be
  punctuation.

## Packaging Lessons

- After packaging changes, verify the final `.app` contents directly with
  `python3 scripts/release_tool.py verify-runtime-resources --app .cache/build/aulycShot.app`
  and, for release builds, confirm both the App and share extension contain only
  the `arm64` slice.

## Icon Assets

- `design/iconMark.svg` is the only geometry source for the menu bar, Dock,
  About, and share-extension icons. Do not hand-edit generated SVG, ICNS, PNG,
  or manifest files.
- After changing icon geometry, run `make icons`; before packaging, run
  `make icon-check`. `scripts/bundle.sh` enforces the same read-only check so
  exact-tag builds never rewrite source files.
- Keep presentation-specific color and stroke width in
  `scripts/icon_assets.py`, while paths and glyph positioning remain in the
  canonical mark. See `docs/ICON_ASSETS.md` for the resource call chain.

## Versioning and Release Profile

- Release profile: `macos-arm64-app` 1.0.0
- Distribution: Developer ID DMG published manually to the private GitHub
  repository `aulyc/aulycShot`
- Architecture: Apple Silicon `arm64` only. Release gates require both the App
  and share extension to contain exactly the `arm64` slice
- Authoritative version and build source: `aulycShot/App/Info.plist`
  (`CFBundleShortVersionString` and `CFBundleVersion`)
- Derived version fields: the assembled App copies the authoritative plist and
  `scripts/bundle.sh` synchronizes the share extension plist during packaging
- Version synchronization: `make prepare-formal-release TARGET_VERSION=... TARGET_BUILD=...`
- Drift check: `make version-check`
- Bundle ID: `com.aulyc.aulycshot`; minimum macOS: 14.0
- Entitlements owners: `scripts/aulycShot.entitlements` and
  `scripts/aulycShot-share-extension.entitlements`
- Release documentation: `docs/RELEASE.md`

## Release Classes

- Local builds use channel `local`, are not releases, and may use ad-hoc
  signing when the stable Developer ID identity is unavailable
- Formal releases use a stable SemVer, a globally increasing positive build,
  a dedicated `chore: release <version>` metadata commit and an immutable
  annotated tag equal to the version without a `v` prefix
- Test releases are currently N/A because this project has no separately
  authorized test distribution channel. Do not rename a local build or formal
  candidate into a release
- Automatic updates and Homebrew distribution are not part of the current
  release channel

## Release Gates

- Candidate gate: `make release-check`
- Create or verify tag: `make release-tag`
- Exact-tag Developer ID build, DMG signing, notarization and provenance:
  `make release-formal DEVELOPER_ID_APPLICATION='Developer ID Application: ...' NOTARY_PROFILE=...`
- Reverify artifact: `make verify-artifact RELEASE_PROVENANCE=/absolute/path/...release-provenance.json`
- Install and verify `/Applications/aulycShot.app`:
  `make install-release RELEASE_PROVENANCE=/absolute/path/...release-provenance.json`
- Read-only installed verification:
  `make verify-installed RELEASE_PROVENANCE=/absolute/path/...release-provenance.json`
- Every formal artifact is rebuilt from an isolated worktree at the exact
  annotated tag. The source must remain clean before and after the build
- Formal App and share extension require Developer ID, timestamp, Hardened
  Runtime and only the `arm64` slice. The signed DMG requires Apple
  notarization `Accepted`, stapling, `stapler validate` and Gatekeeper
- Release provenance is `*.release-provenance.json`, records `dirty: false`,
  and is independently checked against Git, the real DMG, mounted App and
  installed App

## GitHub Source Publication

- Central binding: `aulyc/aulycShot`, remote `origin`, branch `main`
- Preflight runs before release metadata changes through
  `scripts/prepare-formal-release.sh`
- Publish only after the exact-tag artifact has been notarized and the formal
  App has been installed and verified
- `make publish-release RELEASE_PROVENANCE=/absolute/path/...release-provenance.json`
  uses the central gate for one atomic, non-force branch and annotated-tag push,
  remote ref readback and provenance finalization, then creates a GitHub Release
  with `--verify-tag`
- The GitHub repository is private. Publishing must not dispatch Homebrew,
  create an automatic-update feed, or make the repository public

## Data Credentials and Compatibility Identities

- Apple certificates, the `notarytool` profile, GitHub CLI OAuth and SSH keys
  remain in host-level credential stores and are never written into this
  repository, product metadata, logs or release provenance
- Installation only replaces `/Applications/aulycShot.app`; it preserves
  preferences, screenshots, history, privacy grants, Keychain data and all
  other user data
- Bundle identifiers and executable names are compatibility identities and
  must not change during release work

## Hotspot Ownership

- `aulycShot/Editor/EditWindowController.swift` owns editor session wiring,
  toolbar callbacks, scroll capture, crop mode, and output actions. Keep tool
  state changes paired with toolbar/sub-toolbar updates. Verify with
  `bash scripts/compile-check.sh`; use `bash scripts/rebuild-and-open.sh` for
  UI interaction changes.
- `aulycShot/Editor/EditCanvasView.swift` owns annotation state, mouse handling,
  selection chrome, undo/redo, and export compositing. Preserve value-typed
  annotation mutation and snapshot-based undo. Verify with
  `bash scripts/compile-check.sh`; use `bash scripts/rebuild-and-open.sh` when
  hit testing or visible editing behavior changes.
- `aulycShot/Editor/Annotations.swift` owns annotation model structs and drawing
  behavior. Keep drawing and hit-testing logic together for each annotation
  type. Verify with `bash scripts/compile-check.sh`.
- `aulycShot/Settings/SettingsView.swift` owns the settings window and preference
  controls. Keep persisted defaults in `Defaults.swift` aligned with visible
  controls and localized strings. Verify with `bash scripts/compile-check.sh`;
  use `bash scripts/rebuild-and-open.sh` for settings UI behavior.
- `aulycShot/Capture/PinLauncher.swift` owns pinned-image window behavior,
  toolbar visibility, drag/resize behavior, and zoom interaction. Keep hover
  affordances and the above/below-100% drag model stable. Verify with
  `bash scripts/compile-check.sh`; use `bash scripts/rebuild-and-open.sh` for
  pin-window interaction changes.
- `aulycShot/Utilities/Defaults.swift` owns persisted preferences and localized
  string accessors. Keep new settings normalized at the persistence boundary and
  add matching keys to every `Resources/*.lproj/Localizable.strings` file.
  Verify with `bash scripts/compile-check.sh`.
- `aulycShot/Trigger/HotkeyManager.swift` owns global shortcut registration and
  keyboard trigger dispatch. Keep shortcut recording, defaults, and active
  registration behavior aligned with Settings. Verify with
  `bash scripts/compile-check.sh`; use `bash scripts/rebuild-and-open.sh` for
  end-to-end hotkey behavior.

## Adding an Editor Tool

Whenever a new annotation/editor tool is added, it MUST also be wired into the
toolbar — a tool that isn't in `ToolbarLayout` never appears for the user.
Checklist:

- Add the `ToolbarItemID` case and update `editTool`, `symbolName`, `tooltip`,
  and the `kind` switch in `ToolbarLayout.swift`.
- Add the case to **both** `ToolbarLayout.canonicalOrder` and the `default`
  layout's `primary`/`side`/`hidden` buckets. A tool missing from
  `canonicalOrder` is invisible even though the enum case exists.
- Add the `tipXxx` localization key to `Defaults.swift` and to every
  `Resources/*.lproj/Localizable.strings` file.
- If the user has not told you where the tool should sit in the toolbar by
  default, **ask before placing it** — don't guess the position.
