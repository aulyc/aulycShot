import argparse
import importlib.util
import json
import plistlib
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "release_tool.py"
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
            "# Changelog\n\n## [Unreleased]\n\n### Fixed\n- Keep the menu item alive\n\n## [1.6.12] - 2026-07-17\n\n- Previous\n",
            encoding="utf-8",
        )
        release_tool.ROOT = self.root
        release_tool.INFO_PLIST = self.info
        release_tool.EXTENSION_INFO_PLIST = self.extension_info
        release_tool.CHANGELOG = self.changelog
        release_tool.ADOPTION = self.adoption

    def tearDown(self):
        self.temporary.cleanup()

    @staticmethod
    def write_plist(path, value):
        with path.open("wb") as handle:
            plistlib.dump(value, handle)

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
        self.assertIn("## [1.6.13] - ", changelog)
        self.assertLess(changelog.index("## [1.6.13]"), changelog.index("### Fixed"))

    def test_prepare_rejects_version_or_build_rollback(self):
        with self.assertRaisesRegex(release_tool.ReleaseError, "target version must be greater"):
            release_tool.command_prepare(argparse.Namespace(version="1.6.11", build=495))
        with self.assertRaisesRegex(release_tool.ReleaseError, "target build must be greater"):
            release_tool.command_prepare(argparse.Namespace(version="1.6.13", build=494))

    def valid_provenance(self, dmg):
        return {
            "releaseProfile": "macos-arm64-app",
            "releaseChannel": "formal",
            "dirty": False,
            "architecture": "universal2",
            "architectures": ["arm64", "x86_64"],
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


if __name__ == "__main__":
    unittest.main()
