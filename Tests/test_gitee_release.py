import importlib.util
import base64
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "gitee_release.py"
SPEC = importlib.util.spec_from_file_location("aulycshot_gitee_release", SCRIPT)
gitee_release = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(gitee_release)


class GiteeReleaseTests(unittest.TestCase):
    def test_client_requires_token_without_exposing_a_value(self):
        with self.assertRaisesRegex(gitee_release.GiteeError, "GITEE_ACCESS_TOKEN"):
            gitee_release.GiteeClient("")

    def test_publish_writes_attachment_identity_for_manifest_generation(self):
        with tempfile.TemporaryDirectory() as temporary_name:
            root = Path(temporary_name)
            notes = root / "notes.md"
            artifact = root / "aulycShot.dmg"
            output = root / "gitee-release.json"
            notes.write_text("Release notes\n", encoding="utf-8")
            artifact.write_bytes(b"formal artifact")
            fake_client = mock.Mock()
            fake_client.ensure_release.return_value = (42, False)
            fake_client.ensure_attachments.return_value = [
                {
                    "file": artifact.name,
                    "id": 99,
                    "downloadURL": (
                        "https://gitee.com/aulyc/aulycShot-releases/releases/download/"
                        "1.7.4/aulycShot.dmg"
                    ),
                }
            ]

            with mock.patch.dict(os.environ, {"GITEE_ACCESS_TOKEN": "not-a-real-token"}):
                with mock.patch.object(gitee_release, "GiteeClient", return_value=fake_client):
                    gitee_release.command_publish(
                        mock.Mock(
                            owner="aulyc",
                            repo="aulycShot-releases",
                            tag="1.7.4",
                            name="aulycShot 1.7.4",
                            notes=notes,
                            files=[artifact],
                            output=output,
                        )
                    )

            value = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(value["releaseId"], 42)
            self.assertEqual(value["attachments"][0]["id"], 99)
            self.assertEqual(value["attachments"][0]["file"], artifact.name)

    def test_existing_release_is_reused_only_when_metadata_matches(self):
        client = object.__new__(gitee_release.GiteeClient)
        client.token = "not-a-real-token"
        client.request_json = mock.Mock(
            return_value=(
                200,
                {
                    "id": 42,
                    "tag_name": "1.7.4",
                    "name": "aulycShot 1.7.4",
                    "body": "Release notes\n",
                    "prerelease": False,
                },
            )
        )

        release_id, created = client.ensure_release(
            "aulyc",
            "aulycShot-releases",
            "1.7.4",
            "aulycShot 1.7.4",
            "Release notes\n",
        )

        self.assertEqual(release_id, 42)
        self.assertFalse(created)

    def test_empty_success_response_for_missing_release_creates_it(self):
        client = object.__new__(gitee_release.GiteeClient)
        client.token = "not-a-real-token"
        client.request_json = mock.Mock(
            side_effect=[
                (200, None),
                (
                    201,
                    {
                        "id": 42,
                        "tag_name": "1.8.0",
                        "name": "aulycShot 1.8.0",
                        "body": "Release notes\n",
                        "prerelease": False,
                    },
                ),
            ]
        )

        release_id, created = client.ensure_release(
            "aulyc",
            "aulycShot-releases",
            "1.8.0",
            "aulycShot 1.8.0",
            "Release notes\n",
        )

        self.assertEqual(release_id, 42)
        self.assertTrue(created)
        self.assertEqual(client.request_json.call_count, 2)
        self.assertEqual(client.request_json.call_args_list[1].args[0], "POST")

    def test_existing_attachment_is_reused_after_hash_readback(self):
        with tempfile.TemporaryDirectory() as temporary_name:
            artifact = Path(temporary_name) / "aulycShot.dmg"
            artifact.write_bytes(b"formal artifact")
            client = object.__new__(gitee_release.GiteeClient)
            client.token = "not-a-real-token"
            client.list_attachments = mock.Mock(
                return_value=[
                    {
                        "file": artifact.name,
                        "id": 99,
                        "downloadURL": "https://gitee.com/aulyc/download",
                    }
                ]
            )
            client.upload_attachment = mock.Mock()
            client.attachment_sha256 = mock.Mock(
                return_value=gitee_release.hashlib.sha256(artifact.read_bytes()).hexdigest()
            )

            records = client.ensure_attachments(
                "aulyc",
                "aulycShot-releases",
                42,
                [artifact],
            )

            self.assertEqual(records[0]["id"], 99)
            client.upload_attachment.assert_not_called()

    def test_conflicting_existing_attachment_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary_name:
            artifact = Path(temporary_name) / "aulycShot.dmg"
            artifact.write_bytes(b"formal artifact")
            client = object.__new__(gitee_release.GiteeClient)
            client.token = "not-a-real-token"
            client.list_attachments = mock.Mock(
                return_value=[
                    {
                        "file": artifact.name,
                        "id": 99,
                        "downloadURL": "https://gitee.com/aulyc/download",
                    }
                ]
            )
            client.attachment_sha256 = mock.Mock(return_value="0" * 64)

            with self.assertRaisesRegex(gitee_release.GiteeError, "readback mismatch"):
                client.ensure_attachments(
                    "aulyc",
                    "aulycShot-releases",
                    42,
                    [artifact],
                )

    def test_updating_manifest_requires_existing_content_sha(self):
        with tempfile.TemporaryDirectory() as temporary_name:
            source = Path(temporary_name) / "latest.json"
            source.write_text("{}\n", encoding="utf-8")
            client = object.__new__(gitee_release.GiteeClient)
            client.token = "not-a-real-token"
            calls = []
            get_count = 0

            def request(method, path, payload=None, allowed_statuses=None):
                nonlocal get_count
                calls.append((method, path, payload))
                if method == "GET":
                    get_count += 1
                    if get_count == 2:
                        return 200, {
                            "sha": "def456",
                            "content": base64.b64encode(source.read_bytes()).decode("ascii"),
                        }
                    return 200, {"sha": "abc123"}
                return 200, {}

            client.request_json = request
            client.put_file(
                "aulyc",
                "aulycShot-releases",
                "latest.json",
                "main",
                source,
                "chore: publish 1.7.4 update manifest",
            )

            self.assertEqual(calls[1][0], "PUT")
            self.assertEqual(calls[1][2]["sha"], "abc123")
            self.assertEqual(calls[1][2]["branch"], "main")

    def test_empty_success_response_for_missing_manifest_creates_it(self):
        with tempfile.TemporaryDirectory() as temporary_name:
            source = Path(temporary_name) / "latest.json"
            source.write_text("{}\n", encoding="utf-8")
            client = object.__new__(gitee_release.GiteeClient)
            client.token = "not-a-real-token"
            calls = []
            get_count = 0

            def request(method, path, payload=None, allowed_statuses=None):
                nonlocal get_count
                calls.append((method, path, payload))
                if method == "GET":
                    get_count += 1
                    if get_count == 2:
                        return 200, {
                            "sha": "def456",
                            "content": base64.b64encode(source.read_bytes()).decode("ascii"),
                        }
                    return 200, []
                return 201, {}

            client.request_json = request
            client.put_file(
                "aulyc",
                "aulycShot-releases",
                "latest.json",
                "main",
                source,
                "chore: publish 1.8.0 update manifest",
            )

            self.assertEqual(calls[1][0], "POST")
            self.assertNotIn("sha", calls[1][2])
            self.assertEqual(calls[1][2]["branch"], "main")


if __name__ == "__main__":
    unittest.main()
