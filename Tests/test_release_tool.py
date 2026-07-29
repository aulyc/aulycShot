import argparse
import importlib.util
import json
import plistlib
import re
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "release_tool.py"
PROJECT_ROOT = SCRIPT.parent.parent
SPEC = importlib.util.spec_from_file_location("aulycshot_release_tool", SCRIPT)
release_tool = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(release_tool)


class ReleaseToolTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.info = self.root / "aulycShot" / "App" / "Info.plist"
        self.extension_info = self.root / "aulycShot-share-extension" / "Info.plist"
        self.changelog = self.root / "CHANGELOG.md"
        self.changelog_zh_cn = self.root / "CHANGELOG.zh-CN.md"
        self.adoption = self.root / ".codex" / "standards.json"
        self.info.parent.mkdir(parents=True)
        self.extension_info.parent.mkdir(parents=True)
        self.adoption.parent.mkdir(parents=True)
        self.write_plist(
            self.info,
            {
                "CFBundleShortVersionString": "1.6.12",
                "CFBundleVersion": "494",
                "CFBundleIdentifier": "com.aulyc.aulycshot",
                "LSMinimumSystemVersion": "14.0",
            },
        )
        self.write_plist(
            self.extension_info,
            {"CFBundleIdentifier": "com.aulyc.aulycshot.shareextension"},
        )
        self.changelog.write_text(
            "# Changelog\n\n## [Unreleased]\n\n### Fixed\n- Keep the menu item alive\n\n## [1.6.12] - 2026-07-17\n\n### Fixed\n\n- Previous\n",
            encoding="utf-8",
        )
        self.changelog_zh_cn.write_text(
            "# 更新日志\n\n## [Unreleased]\n\n### 修复\n- 保持菜单项可用\n\n## [1.6.12] - 2026-07-17\n\n### 修复\n\n- 之前的版本\n",
            encoding="utf-8",
        )
        release_tool.ROOT = self.root
        release_tool.INFO_PLIST = self.info
        release_tool.EXTENSION_INFO_PLIST = self.extension_info
        release_tool.CHANGELOG = self.changelog
        release_tool.CHANGELOG_ZH_CN = self.changelog_zh_cn
        release_tool.ADOPTION = self.adoption

    def tearDown(self):
        self.temporary.cleanup()

    @staticmethod
    def write_plist(path, value):
        with path.open("wb") as handle:
            plistlib.dump(value, handle)

    def write_runtime_icons(self, app):
        values = {
            Path("Resources/AppIcon.icns"): b"generated application icon",
            Path("design/menuBarIcon.svg"): b"generated menu bar icon",
        }
        for relative, value in values.items():
            source = self.root / relative
            source.parent.mkdir(parents=True, exist_ok=True)
            source.write_bytes(value)
        for source_relative, bundled_relative in release_tool.RUNTIME_ICON_RESOURCES:
            bundled = app / bundled_relative
            bundled.parent.mkdir(parents=True, exist_ok=True)
            bundled.write_bytes(values[source_relative])

    def test_version_identity_accepts_authoritative_version_and_build(self):
        self.assertEqual(release_tool.version_identity(), ("1.6.12", 494))

    def test_version_identity_rejects_noncanonical_build(self):
        value = release_tool.read_plist(self.info)
        value["CFBundleVersion"] = "0494"
        self.write_plist(self.info, value)

        with self.assertRaisesRegex(release_tool.ReleaseError, "canonical positive integer"):
            release_tool.version_identity()

    def test_prepare_moves_unreleased_notes_and_increments_both_identities(self):
        release_tool.command_prepare(argparse.Namespace(version="1.6.13", build=495))

        self.assertEqual(release_tool.version_identity(require_stable=True), ("1.6.13", 495))
        changelog = self.changelog.read_text(encoding="utf-8")
        changelog_zh_cn = self.changelog_zh_cn.read_text(encoding="utf-8")
        self.assertIn("## [1.6.13] - ", changelog)
        self.assertLess(changelog.index("## [1.6.13]"), changelog.index("### Fixed"))
        self.assertIn("## [1.6.13] - ", changelog_zh_cn)
        self.assertLess(changelog_zh_cn.index("## [1.6.13]"), changelog_zh_cn.index("### 修复"))

    def test_prepare_rejects_empty_chinese_unreleased_section(self):
        self.changelog_zh_cn.write_text(
            "# 更新日志\n\n## [Unreleased]\n\n## [1.6.12] - 2026-07-17\n\n- 之前的版本\n",
            encoding="utf-8",
        )

        with self.assertRaisesRegex(
            release_tool.ReleaseError,
            "CHANGELOG.zh-CN.md Unreleased section is empty",
        ):
            release_tool.command_prepare(argparse.Namespace(version="1.6.13", build=495))

        self.assertEqual(release_tool.version_identity(), ("1.6.12", 494))

    def test_github_release_notes_put_chinese_before_english(self):
        output = self.root / "github-notes.md"

        release_tool.command_release_notes(
            argparse.Namespace(version="1.6.12", channel="github", output=output)
        )

        notes = output.read_text(encoding="utf-8")
        self.assertTrue(notes.startswith("## 中文\n\n"))
        self.assertIn("### 修复\n\n- 之前的版本", notes)
        self.assertIn("\n---\n\n## English\n\n", notes)
        self.assertIn("- Previous", notes)
        self.assertLess(notes.index("### 修复"), notes.index("## English"))

    def test_gitee_release_notes_are_chinese_only(self):
        output = self.root / "gitee-notes.md"

        release_tool.command_release_notes(
            argparse.Namespace(version="1.6.12", channel="gitee", output=output)
        )

        notes = output.read_text(encoding="utf-8")
        self.assertEqual(notes, "### 修复\n\n- 之前的版本\n")
        self.assertNotIn("Previous", notes)

    def test_publish_scripts_route_bilingual_and_chinese_notes_by_platform(self):
        canonical = (PROJECT_ROOT / "scripts" / "publish-release.sh").read_text(
            encoding="utf-8"
        )
        mirrors = (PROJECT_ROOT / "scripts" / "publish-update-mirrors.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn("--channel github --output \"$GITHUB_NOTES\"", canonical)
        self.assertIn("--channel gitee --output \"$GITEE_NOTES\"", canonical)
        self.assertIn("--notes-file \"$GITHUB_NOTES\"", canonical)
        self.assertIn("--notes-file \"$GITHUB_NOTES\"", mirrors)
        self.assertIn("--notes \"$GITEE_NOTES\"", mirrors)

    def test_prepare_rejects_version_or_build_rollback(self):
        with self.assertRaisesRegex(release_tool.ReleaseError, "target version must be greater"):
            release_tool.command_prepare(argparse.Namespace(version="1.6.11", build=495))
        with self.assertRaisesRegex(release_tool.ReleaseError, "target build must be greater"):
            release_tool.command_prepare(argparse.Namespace(version="1.6.13", build=494))

    def test_codesign_runtime_parser_matches_real_code_directory_line(self):
        signed = "CodeDirectory v=20500 size=10079 flags=0x10000(runtime) hashes=304+7 location=embedded"
        unsigned = "CodeDirectory v=20400 size=10079 flags=0x0(none) hashes=304+7 location=embedded"

        self.assertTrue(release_tool.codesign_has_runtime(signed))
        self.assertFalse(release_tool.codesign_has_runtime(unsigned))

    def test_developer_id_signing_uses_explicit_apple_timestamp_service(self):
        bundle_script = (PROJECT_ROOT / "scripts" / "bundle.sh").read_text(encoding="utf-8")
        formal_script = (PROJECT_ROOT / "scripts" / "formal-release.sh").read_text(encoding="utf-8")
        expected_url = "http://timestamp.apple.com/ts01"

        self.assertIn(f'APPLE_TIMESTAMP_URL="${{APPLE_TIMESTAMP_URL:-{expected_url}}}"', bundle_script)
        self.assertIn('local timestamp_option="--timestamp=$APPLE_TIMESTAMP_URL"', bundle_script)
        self.assertIn(f'APPLE_TIMESTAMP_URL="${{APPLE_TIMESTAMP_URL:-{expected_url}}}"', formal_script)
        self.assertIn('"--timestamp=$APPLE_TIMESTAMP_URL"', formal_script)

    def test_runtime_resources_accept_packaged_icons(self):
        app = self.root / "aulycShot.app"
        self.write_runtime_icons(app)

        release_tool.verify_runtime_resources(app)

    def test_runtime_resources_reject_stale_packaged_icon(self):
        app = self.root / "aulycShot.app"
        self.write_runtime_icons(app)
        (app / "Contents" / "Resources" / "AppIcon.icns").write_bytes(b"stale")

        with self.assertRaisesRegex(release_tool.ReleaseError, "does not match generated source"):
            release_tool.verify_runtime_resources(app)

    def valid_provenance(self, dmg):
        return {
            "releaseProfile": "macos-arm64-app",
            "releaseChannel": "formal",
            "dirty": False,
            "architecture": "arm64",
            "architectures": ["arm64"],
            "bundleIdentifier": "com.aulyc.aulycshot",
            "hardenedRuntime": True,
            "notarized": True,
            "stapled": True,
            "gatekeeperAccepted": True,
            "version": "1.6.13",
            "tag": "1.6.13",
            "buildNumber": 495,
            "commit": "a" * 40,
            "artifacts": [{"file": dmg.name, "sha256": release_tool.sha256(dmg)}],
        }

    def test_validate_provenance_accepts_matching_dmg(self):
        dmg = self.root / "aulycShot.dmg"
        dmg.write_bytes(b"formal artifact")
        provenance = self.root / "release-provenance.json"
        provenance.write_text(json.dumps(self.valid_provenance(dmg)), encoding="utf-8")

        value, resolved_dmg = release_tool.validate_provenance(provenance)

        self.assertEqual(value["version"], "1.6.13")
        self.assertEqual(resolved_dmg, dmg)

    def test_validate_provenance_rejects_tampered_dmg(self):
        dmg = self.root / "aulycShot.dmg"
        dmg.write_bytes(b"formal artifact")
        provenance = self.root / "release-provenance.json"
        provenance.write_text(json.dumps(self.valid_provenance(dmg)), encoding="utf-8")
        dmg.write_bytes(b"tampered")

        with self.assertRaisesRegex(release_tool.ReleaseError, "DMG SHA-256"):
            release_tool.validate_provenance(provenance)

    def test_validate_provenance_rejects_non_arm64_artifact(self):
        dmg = self.root / "aulycShot.dmg"
        dmg.write_bytes(b"formal artifact")
        value = self.valid_provenance(dmg)
        value["architecture"] = "universal2"
        value["architectures"] = ["arm64", "x86_64"]
        provenance = self.root / "release-provenance.json"
        provenance.write_text(json.dumps(value), encoding="utf-8")

        with self.assertRaisesRegex(release_tool.ReleaseError, "field architecture"):
            release_tool.validate_provenance(provenance)

    def test_write_update_manifest_binds_same_artifact_to_both_mirrors(self):
        dmg = self.root / "aulycShot-1.6.13-build.495-arm64.dmg"
        dmg.write_bytes(b"formal artifact")
        value = self.valid_provenance(dmg)
        value.update(
            {
                "teamIdentifier": "M9M7M2ARFD",
                "minimumSystemVersion": "14.0",
            }
        )
        provenance = self.root / "release-provenance.json"
        provenance.write_text(json.dumps(value), encoding="utf-8")
        output = self.root / "latest.json"
        github_url = (
            "https://github.com/aulyc/aulycShot-releases/releases/download/"
            "1.6.13/aulycShot-1.6.13-build.495-arm64.dmg"
        )
        gitee_url = (
            "https://gitee.com/aulyc/aulycShot-releases/releases/download/"
            "1.6.13/aulycShot-1.6.13-build.495-arm64.dmg"
        )

        release_tool.command_write_update_manifest(
            argparse.Namespace(
                provenance=provenance,
                github_url=github_url,
                gitee_url=gitee_url,
                release_page_url=None,
                output=output,
            )
        )

        manifest = json.loads(output.read_text(encoding="utf-8"))
        self.assertEqual(manifest["version"], "1.6.13")
        self.assertEqual(manifest["buildNumber"], 495)
        self.assertEqual(manifest["artifact"]["file"], dmg.name)
        self.assertEqual(
            [item["source"] for item in manifest["artifact"]["downloads"]],
            ["github", "gitee"],
        )
        self.assertEqual(
            {item["url"] for item in manifest["artifact"]["downloads"]},
            {github_url, gitee_url},
        )

    def test_write_update_manifest_rejects_non_github_primary_url(self):
        dmg = self.root / "aulycShot-1.6.13-build.495-arm64.dmg"
        dmg.write_bytes(b"formal artifact")
        value = self.valid_provenance(dmg)
        value.update(
            {
                "teamIdentifier": "M9M7M2ARFD",
                "minimumSystemVersion": "14.0",
            }
        )
        provenance = self.root / "release-provenance.json"
        provenance.write_text(json.dumps(value), encoding="utf-8")

        with self.assertRaisesRegex(release_tool.ReleaseError, "github.com"):
            release_tool.command_write_update_manifest(
                argparse.Namespace(
                    provenance=provenance,
                    github_url="https://gitee.com/not-primary.dmg",
                    gitee_url="https://gitee.com/fallback.dmg",
                    release_page_url=None,
                    output=self.root / "latest.json",
                )
            )

    def test_write_update_manifest_rejects_another_github_repository(self):
        dmg = self.root / "aulycShot-1.6.13-build.495-arm64.dmg"
        dmg.write_bytes(b"formal artifact")
        value = self.valid_provenance(dmg)
        value.update(
            {
                "teamIdentifier": "M9M7M2ARFD",
                "minimumSystemVersion": "14.0",
            }
        )
        provenance = self.root / "release-provenance.json"
        provenance.write_text(json.dumps(value), encoding="utf-8")

        with self.assertRaisesRegex(release_tool.ReleaseError, "configured public mirror"):
            release_tool.command_write_update_manifest(
                argparse.Namespace(
                    provenance=provenance,
                    github_url=(
                        "https://github.com/other/project/releases/download/"
                        "1.6.13/aulycShot-1.6.13-build.495-arm64.dmg"
                    ),
                    gitee_url=(
                        "https://gitee.com/aulyc/aulycShot-releases/releases/download/"
                        "1.6.13/aulycShot-1.6.13-build.495-arm64.dmg"
                    ),
                    release_page_url=None,
                    output=self.root / "latest.json",
                )
            )

    def test_refresh_standards_hashes_only_declared_files(self):
        controlled = self.root / "Makefile"
        controlled.write_text("version-check:\n", encoding="utf-8")
        self.adoption.write_text(
            json.dumps({"trackedFiles": [{"path": "Makefile", "sha256": "0" * 64}]}),
            encoding="utf-8",
        )

        release_tool.command_refresh_standards(argparse.Namespace())

        updated = json.loads(self.adoption.read_text(encoding="utf-8"))
        self.assertEqual(updated["trackedFiles"][0]["sha256"], release_tool.sha256(controlled))

    def test_release_metadata_files_are_not_fixed_hash_controls(self):
        adoption = json.loads(
            (PROJECT_ROOT / ".codex" / "standards.json").read_text(encoding="utf-8")
        )
        tracked_paths = {item["path"] for item in adoption["trackedFiles"]}

        self.assertNotIn("CHANGELOG.md", tracked_paths)
        self.assertNotIn("CHANGELOG.zh-CN.md", tracked_paths)
        self.assertNotIn("aulycShot/App/Info.plist", tracked_paths)


if __name__ == "__main__":
    unittest.main()
