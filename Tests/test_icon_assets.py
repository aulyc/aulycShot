import importlib.util
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = PROJECT_ROOT / "scripts" / "icon_assets.py"
SPEC = importlib.util.spec_from_file_location("aulycshot_icon_assets", SCRIPT)
icon_assets = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(icon_assets)


class IconAssetTests(unittest.TestCase):
    def test_generated_svgs_share_the_canonical_geometry_and_glyph_position(self):
        _, frame_paths, glyph_paths, glyph_transform = icon_assets.read_mark(PROJECT_ROOT)
        menu_bar, app_icon = icon_assets.build_svg_documents(PROJECT_ROOT)

        for data in frame_paths + glyph_paths:
            self.assertIn(f'd="{data}"', menu_bar)
            self.assertIn(f'd="{data}"', app_icon)
        self.assertIn(f'transform="{glyph_transform}"', menu_bar)
        self.assertIn(f'transform="{glyph_transform}"', app_icon)
        self.assertNotIn("<rect", menu_bar)
        self.assertIn('stroke="#000000"', menu_bar)
        self.assertIn('<rect width="1024" height="1024" fill="#2E2E31"/>', app_icon)

    def test_repository_icon_assets_are_synchronized(self):
        icon_assets.verify_assets(PROJECT_ROOT)

    def test_manifest_covers_every_generated_output(self):
        value = icon_assets.manifest_value(PROJECT_ROOT)
        recorded = {item["file"] for item in value["generatedOutputs"]}
        expected = {path.as_posix() for path in icon_assets.GENERATED_OUTPUTS}

        self.assertEqual(recorded, expected)


if __name__ == "__main__":
    unittest.main()
