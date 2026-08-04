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
It launches the local `.cache/build/aulycShot.app` directly and must not write to `/Applications`;
formal installation is a separate, explicitly authorized `make install-release` operation.

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

- Release profile: `macos-arm64-app` 2.0.0
- Distribution: public GitHub repository `aulyc/aulycShot` is the sole source
  authority and GitHub Release repository; Gitee `aulyc/aulycShot` is
  release-only with no source push
- Architecture: Apple Silicon `arm64` only. Release gates require both the App
  and share extension to contain exactly the `arm64` slice
- Authoritative version and build source: `aulycShot/App/Info.plist`
  (`CFBundleShortVersionString` and `CFBundleVersion`)
- Derived version fields: the assembled App copies the authoritative plist and
  `scripts/bundle.sh` synchronizes the share extension plist during packaging
- Version synchronization: `make prepare-formal-release TARGET_VERSION=... TARGET_BUILD=...`
- Release notes: English entries live in `CHANGELOG.md`, Simplified Chinese
  entries live in `CHANGELOG.zh-CN.md`; GitHub Releases publish Chinese first
  and English second, while Gitee Releases publish Simplified Chinese only
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
- Automatic updates use identical public `latest.json` manifests with GitHub
  first and Gitee fallback. Homebrew distribution is not part of the current
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
- Recoverable public-mirror publication:
  `make publish-update-mirrors RELEASE_PROVENANCE=/absolute/path/...release-provenance.json`
- Every formal artifact is rebuilt from an isolated worktree at the exact
  annotated tag. The source must remain clean before and after the build
- Formal App and share extension require Developer ID, timestamp, Hardened
  Runtime and only the `arm64` slice. The signed DMG requires Apple
  notarization `Accepted`, stapling, `stapler validate` and Gatekeeper
- Release provenance is `*.release-provenance.json`, records `dirty: false`,
  and is independently checked against Git, the real DMG and mounted App.
  Installed-App checks run only for an explicitly requested installation.
- `正式发版` and `完整发版` build, publish and read back the formal release but
  never write `/Applications`. `正式发版安装` performs that release first and
  then runs `make install-release` for its exact provenance. `安装正式版`
  installs an existing verified formal provenance without creating a release.
  Test release operations are not supported. Pure release reports
  `installationStatus: not-requested`.

## GitHub Source Publication

- Central binding: `aulyc/aulycShot`, remote `origin`, branch `main`
- Preflight runs before release metadata changes through
  `scripts/prepare-formal-release.sh`
- Publish after the exact-tag artifact has been notarized and independently
  verified from the DMG; installation is not a publication prerequisite
- `make publish-release RELEASE_PROVENANCE=/absolute/path/...release-provenance.json`
  uses the central gate for one atomic, non-force branch and annotated-tag push,
  remote ref readback and provenance finalization, then delegates public
  GitHub/Gitee publication and readback to the central dual-mirror tool
- The canonical GitHub source repository is the only public source authority
  and GitHub Release repository; Gitee remains a release-only distribution
  repository and must point users to GitHub source
- Both mirrors must receive the same already-notarized DMG, checksum,
  provenance, provenance checksum and `latest.json`. The manifest binds
  version, build, Commit, Bundle ID, architecture, artifact/provenance
  SHA-256, and fixed GitHub-then-Gitee download order; Team ID and minimum
  system are independently checked against the downloaded App/provenance.
- Public GitHub Release descriptions are Chinese-first/English-second; the
  Gitee Release description uses the matching Simplified Chinese notes.
- `GITEE_ACCESS_TOKEN` is a host credential read only by the central client; it
  must never be printed or written into the repository, product metadata,
  plans, state, logs or provenance.
- Publishing must not dispatch Homebrew or rebuild a separate Gitee artifact

## Dual-mirror release policy

- Explicit policy: `aulyc-dual-mirror-v1` `1.6.0`; the Release Profile remains
  `macos-arm64-app`.
- Project adapter: `scripts/dual-mirror-release.sh` only binds project ID
  `aulycshot`; `scripts/publish-update-mirrors.sh` composes the central
  `prepare`, `preflight`, `publish`, and `verify` phases.
- Full mapping and retry contract: `docs/DUAL_MIRROR_RELEASE.md`.
- The updater loads the central `latest.json` Schema, downloads and verifies
  the release provenance before the DMG, then verifies the installed App.
- The updater tries the GitHub manifest first and the Gitee manifest second;
  retired compatibility repositories are not valid release identities or
  update endpoints
- Only an explicitly authorized `publish` may write remote state. One-sided
  failure records partial/failed state and retries the same immutable plan;
  never push source to Gitee or overwrite an old release.

## Data Credentials and Compatibility Identities

- Apple certificates, the `notarytool` profile, GitHub CLI OAuth and SSH keys,
  and the Gitee API token remain in host-level credential stores and are never
  written into this repository, product metadata, logs or release provenance
- Installation only replaces `/Applications/aulycShot.app`; it preserves
  preferences, screenshots, history, privacy grants, Keychain data and all
  other user data
- Bundle identifiers and executable names are compatibility identities and
  must not change during release work

## Hotspot Ownership

- `aulycShot/Editor/EditWindowController.swift` owns editor session wiring,
  crop/output orchestration, and collaborator callbacks. Editor chrome lives in
  `EditorKeyboardShortcut.swift`, `EditorOptionChrome.swift`, `ToolbarView.swift`,
  `ToolButton.swift`, `EditorSubToolbars.swift`, `EditorHUDControls.swift`,
  `SelectionChromeOverlay.swift`, and the `Scroll*.swift` controls. Keep tool
  state changes paired with toolbar/sub-toolbar updates. Verify with
  `bash scripts/compile-check.sh`; use `bash scripts/rebuild-and-open.sh` for
  UI interaction changes.
- `aulycShot/Editor/EditCanvasView.swift` owns annotation state, mouse handling,
  and selection interaction. Hit testing, snapshot history, export compositing,
  cursors, edit tools, and live text editing live in their named collaborators.
  Preserve value-typed annotation mutation and snapshot-based undo. Verify with
  `bash scripts/compile-check.sh`; use `bash scripts/rebuild-and-open.sh` when
  hit testing or visible editing behavior changes.
- `aulycShot/Editor/Annotations.swift` owns the annotation protocol and shared
  geometry. Each `*Annotation.swift` file owns that type's model, drawing, and
  hit testing; keep those responsibilities together. Verify with
  `bash scripts/compile-check.sh`.
- `aulycShot/Settings/SettingsView.swift` owns settings-window orchestration and
  shared pane state. General, shortcut, permission, and about behavior live in
  their matching `*SettingsPane.swift` files; chrome, builders, and controls
  live in `SettingsChrome.swift` and `SettingsShared*.swift`. Keep persisted
  defaults in `Defaults.swift` aligned with visible controls and localized
  strings. Verify with `bash scripts/compile-check.sh`;
  use `bash scripts/rebuild-and-open.sh` for settings UI behavior.
- `aulycShot/Capture/PinLauncher.swift` owns pin creation only. Window lifetime,
  image interaction, navigation, toolbar, text pins, and pure zoom/viewport
  geometry live in `PinWindow*.swift`, `PinContentView.swift`,
  `PinNavigatorView.swift`, `PinToolbar.swift`, `TextPin.swift`, and
  `PinZoomPolicy.swift`. Keep hover affordances and the above/below-100% drag
  model stable. Verify with
  `bash scripts/compile-check.sh`; use `bash scripts/rebuild-and-open.sh` for
  pin-window interaction changes.
- `aulycShot/Capture/RecordingEngine.swift` owns main-thread recording lifecycle
  and ScreenCaptureKit coordination. `RecordingWriterCoordinator.swift` owns
  queue serialization, while `RecordingWriterSession.swift` and
  `RecordingWriterBackend.swift` own writer state and AVFoundation I/O. Keep all
  writer mutation on the recording queue and completion delivery single-shot.
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
