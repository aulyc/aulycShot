#!/usr/bin/env python3
"""Minimal Gitee release-mirror client with credential-safe process arguments."""

from __future__ import annotations

import argparse
import base64
import hashlib
import http.client
import json
import mimetypes
import os
import tempfile
import uuid
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen


API_HOST = "gitee.com"
API_PREFIX = "/api/v5"
DEFAULT_OWNER = "aulyc"
DEFAULT_REPOSITORY = "aulycShot-releases"


class GiteeError(Exception):
    pass


def atomic_write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}-",
        suffix=".tmp",
        dir=path.parent,
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            json.dump(value, handle, ensure_ascii=False, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


class GiteeClient:
    def __init__(self, token: str):
        if not token:
            raise GiteeError("GITEE_ACCESS_TOKEN is required")
        self.token = token

    def request_json(
        self,
        method: str,
        path: str,
        payload: dict | None = None,
        *,
        allowed_statuses: set[int] | None = None,
    ) -> tuple[int, dict | list | None]:
        allowed = allowed_statuses or {200, 201}
        data = None
        headers = {
            "Accept": "application/json",
            "Authorization": f"Bearer {self.token}",
            "User-Agent": "aulycShot-release-mirror",
        }
        if payload is not None:
            data = json.dumps(payload, separators=(",", ":")).encode("utf-8")
            headers["Content-Type"] = "application/json"
        request = Request(
            f"https://{API_HOST}{API_PREFIX}{path}",
            data=data,
            headers=headers,
            method=method,
        )
        try:
            with urlopen(request, timeout=60) as response:
                status = response.status
                body = response.read()
        except HTTPError as exc:
            status = exc.code
            body = exc.read()
        except URLError as exc:
            raise GiteeError(f"Gitee API transport failed for {path}") from exc
        if status not in allowed:
            raise GiteeError(f"Gitee API returned HTTP {status} for {path}")
        if not body:
            return status, None
        try:
            return status, json.loads(body)
        except json.JSONDecodeError as exc:
            raise GiteeError(f"Gitee API returned invalid JSON for {path}") from exc

    def ensure_public_repository(self, owner: str, repo: str, description: str) -> None:
        repo_path = f"/repos/{quote(owner)}/{quote(repo)}"
        status, value = self.request_json(
            "GET",
            repo_path,
            allowed_statuses={200, 404},
        )
        if status == 200:
            if not isinstance(value, dict) or value.get("private") is not False:
                raise GiteeError(f"{owner}/{repo} exists but is not public")
            return
        if owner != DEFAULT_OWNER:
            raise GiteeError("automatic repository creation only supports the authenticated owner")
        self.request_json(
            "POST",
            "/user/repos",
            {
                "name": repo,
                "description": description,
                "private": False,
                "auto_init": True,
            },
        )

    def verify_public_repository(self, owner: str, repo: str) -> None:
        _, value = self.request_json(
            "GET",
            f"/repos/{quote(owner)}/{quote(repo)}",
        )
        if not isinstance(value, dict) or value.get("private") is not False:
            raise GiteeError(f"{owner}/{repo} is missing or is not public")

    def ensure_release(
        self,
        owner: str,
        repo: str,
        tag: str,
        name: str,
        body: str,
    ) -> tuple[int, bool]:
        encoded_tag = quote(tag, safe="")
        status, existing = self.request_json(
            "GET",
            f"/repos/{quote(owner)}/{quote(repo)}/releases/tags/{encoded_tag}",
            allowed_statuses={200, 404},
        )
        # Gitee returns HTTP 200 with an empty body when the tag has no release.
        # Treat that response as a miss and continue with release creation.
        if status == 200 and existing is not None:
            if not isinstance(existing, dict) or not isinstance(existing.get("id"), int):
                raise GiteeError(f"Gitee mirror release {tag} has no integer id")
            if (
                existing.get("tag_name") != tag
                or existing.get("name") != name
                or existing.get("body") != body
                or existing.get("prerelease") is not False
            ):
                raise GiteeError(f"Gitee mirror release {tag} does not match the requested release")
            return existing["id"], False
        _, value = self.request_json(
            "POST",
            f"/repos/{quote(owner)}/{quote(repo)}/releases",
            {
                "tag_name": tag,
                "target_commitish": "main",
                "name": name,
                "body": body,
                "prerelease": False,
            },
        )
        if not isinstance(value, dict) or not isinstance(value.get("id"), int):
            raise GiteeError("Gitee release response has no integer id")
        return value["id"], True

    @staticmethod
    def attachment_record(value: dict) -> dict:
        attachment_id = value.get("id")
        name = value.get("name")
        download_url = value.get("browser_download_url")
        if not isinstance(attachment_id, int) or not isinstance(name, str) or not name:
            raise GiteeError("Gitee attachment response has invalid identity")
        if not isinstance(download_url, str) or not download_url.startswith("https://gitee.com/"):
            download_url = ""
        return {
            "file": name,
            "id": attachment_id,
            "downloadURL": download_url,
        }

    def list_attachments(self, owner: str, repo: str, release_id: int) -> list[dict]:
        path = (
            f"/repos/{quote(owner)}/{quote(repo)}/releases/{release_id}/attach_files?"
            f"{urlencode({'page': 1, 'per_page': 100, 'direction': 'asc'})}"
        )
        _, value = self.request_json("GET", path)
        if not isinstance(value, list):
            raise GiteeError("Gitee attachment list is not an array")
        records = []
        for item in value:
            if not isinstance(item, dict):
                raise GiteeError("Gitee attachment list contains an invalid item")
            record = self.attachment_record(item)
            if not record["downloadURL"]:
                raise GiteeError(f"Gitee attachment has no public download URL: {record['file']}")
            records.append(record)
        return records

    @staticmethod
    def file_sha256(file: Path) -> str:
        digest = hashlib.sha256()
        with file.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
        return digest.hexdigest()

    def attachment_sha256(
        self,
        owner: str,
        repo: str,
        release_id: int,
        attachment_id: int,
    ) -> str:
        path = (
            f"/repos/{quote(owner)}/{quote(repo)}/releases/{release_id}/"
            f"attach_files/{attachment_id}/download"
        )
        request = Request(
            f"https://{API_HOST}{API_PREFIX}{path}",
            headers={
                "Accept": "application/octet-stream",
                "Authorization": f"Bearer {self.token}",
                "User-Agent": "aulycShot-release-mirror",
            },
            method="GET",
        )
        digest = hashlib.sha256()
        try:
            with urlopen(request, timeout=300) as response:
                for chunk in iter(lambda: response.read(1024 * 1024), b""):
                    digest.update(chunk)
        except (HTTPError, URLError) as exc:
            raise GiteeError(
                f"Gitee attachment download failed for id {attachment_id}"
            ) from exc
        return digest.hexdigest()

    def ensure_attachments(
        self,
        owner: str,
        repo: str,
        release_id: int,
        files: list[Path],
    ) -> list[dict]:
        expected = {file.name: file.resolve() for file in files}
        if len(expected) != len(files):
            raise GiteeError("release attachments must have unique file names")
        existing_records = self.list_attachments(owner, repo, release_id)
        existing = {record["file"]: record for record in existing_records}
        if len(existing) != len(existing_records):
            raise GiteeError("Gitee release contains duplicate attachment names")
        unexpected = sorted(set(existing) - set(expected))
        if unexpected:
            raise GiteeError(
                f"Gitee release contains unexpected attachments: {', '.join(unexpected)}"
            )

        records = []
        for name, file in expected.items():
            if not file.is_file():
                raise GiteeError(f"release attachment is missing: {file}")
            record = existing.get(name)
            if record is None:
                record = self.upload_attachment(owner, repo, release_id, file)
            local_digest = self.file_sha256(file)
            remote_digest = self.attachment_sha256(
                owner,
                repo,
                release_id,
                record["id"],
            )
            if remote_digest != local_digest:
                raise GiteeError(f"Gitee attachment readback mismatch for {name}")
            records.append(record)
        return records

    def upload_attachment(
        self,
        owner: str,
        repo: str,
        release_id: int,
        file: Path,
    ) -> dict:
        if not file.is_file():
            raise GiteeError(f"release attachment is missing: {file}")
        boundary = f"aulycShot-{uuid.uuid4().hex}"
        content_type = mimetypes.guess_type(file.name)[0] or "application/octet-stream"
        prefix = (
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="file"; filename="{file.name}"\r\n'
            f"Content-Type: {content_type}\r\n\r\n"
        ).encode("utf-8")
        suffix = f"\r\n--{boundary}--\r\n".encode("utf-8")
        path = (
            f"{API_PREFIX}/repos/{quote(owner)}/{quote(repo)}/releases/"
            f"{release_id}/attach_files"
        )
        connection = http.client.HTTPSConnection(API_HOST, timeout=300)
        try:
            connection.putrequest("POST", path)
            connection.putheader("Accept", "application/json")
            connection.putheader("Authorization", f"Bearer {self.token}")
            connection.putheader("User-Agent", "aulycShot-release-mirror")
            connection.putheader("Content-Type", f"multipart/form-data; boundary={boundary}")
            connection.putheader("Content-Length", str(len(prefix) + file.stat().st_size + len(suffix)))
            connection.endheaders()
            connection.send(prefix)
            with file.open("rb") as handle:
                for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                    connection.send(chunk)
            connection.send(suffix)
            response = connection.getresponse()
            body = response.read()
        finally:
            connection.close()
        if response.status not in {200, 201}:
            raise GiteeError(
                f"Gitee API returned HTTP {response.status} while uploading {file.name}"
            )
        try:
            value = json.loads(body)
        except json.JSONDecodeError as exc:
            raise GiteeError(f"Gitee upload returned invalid JSON for {file.name}") from exc
        if not isinstance(value, dict):
            raise GiteeError(f"Gitee upload response is invalid for {file.name}")
        record = self.attachment_record(value)
        if record["file"] != file.name:
            raise GiteeError(f"Gitee upload response changed the file name for {file.name}")
        if not record["downloadURL"]:
            raise GiteeError(f"Gitee upload returned no public download URL for {file.name}")
        return record

    def put_file(
        self,
        owner: str,
        repo: str,
        path: str,
        branch: str,
        source: Path,
        message: str,
    ) -> None:
        if not source.is_file():
            raise GiteeError(f"manifest file is missing: {source}")
        encoded_path = quote(path, safe="/")
        api_path = f"/repos/{quote(owner)}/{quote(repo)}/contents/{encoded_path}"
        status, current = self.request_json(
            "GET",
            f"{api_path}?{urlencode({'ref': branch})}",
            allowed_statuses={200, 404},
        )
        payload = {
            "branch": branch,
            "content": base64.b64encode(source.read_bytes()).decode("ascii"),
            "message": message,
        }
        # Missing content can also be reported as HTTP 200 with an empty body
        # or an empty array.
        content_missing = status == 404 or current is None or current == []
        if not content_missing:
            if not isinstance(current, dict) or not isinstance(current.get("sha"), str):
                raise GiteeError(f"Gitee content response has no sha for {path}")
            payload["sha"] = current["sha"]
            self.request_json("PUT", api_path, payload)
        else:
            self.request_json("POST", api_path, payload)
        _, written = self.request_json(
            "GET",
            f"{api_path}?{urlencode({'ref': branch})}",
        )
        if not isinstance(written, dict) or written.get("content") is None:
            raise GiteeError(f"Gitee did not return written content for {path}")
        encoded = str(written["content"]).replace("\n", "")
        try:
            readback = base64.b64decode(encoded)
        except ValueError as exc:
            raise GiteeError(f"Gitee returned invalid base64 for {path}") from exc
        if readback != source.read_bytes():
            raise GiteeError(f"Gitee readback does not match {path}")


def command_setup(args: argparse.Namespace) -> None:
    client = GiteeClient(os.environ.get("GITEE_ACCESS_TOKEN", ""))
    client.ensure_public_repository(args.owner, args.repo, args.description)
    print(f"Gitee public mirror ready: {args.owner}/{args.repo}")


def command_publish(args: argparse.Namespace) -> None:
    client = GiteeClient(os.environ.get("GITEE_ACCESS_TOKEN", ""))
    notes = args.notes.read_text(encoding="utf-8")
    release_id, _ = client.ensure_release(
        args.owner,
        args.repo,
        args.tag,
        args.name,
        notes,
    )
    attachments = client.ensure_attachments(
        args.owner,
        args.repo,
        release_id,
        [file.resolve() for file in args.files],
    )
    value = {
        "owner": args.owner,
        "repository": args.repo,
        "tag": args.tag,
        "releaseId": release_id,
        "attachments": attachments,
    }
    atomic_write_json(args.output.resolve(), value)
    print(args.output.resolve())


def command_verify(args: argparse.Namespace) -> None:
    client = GiteeClient(os.environ.get("GITEE_ACCESS_TOKEN", ""))
    client.verify_public_repository(args.owner, args.repo)
    print(f"Gitee public mirror verified: {args.owner}/{args.repo}")


def command_put_file(args: argparse.Namespace) -> None:
    client = GiteeClient(os.environ.get("GITEE_ACCESS_TOKEN", ""))
    client.put_file(
        args.owner,
        args.repo,
        args.path,
        args.branch,
        args.file.resolve(),
        args.message,
    )
    print(f"Updated Gitee {args.owner}/{args.repo}:{args.path}")


def make_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    setup = subparsers.add_parser("setup-repository")
    setup.add_argument("--owner", default=DEFAULT_OWNER)
    setup.add_argument("--repo", default=DEFAULT_REPOSITORY)
    setup.add_argument(
        "--description",
        default="Public signed update artifacts for aulycShot",
    )
    setup.set_defaults(func=command_setup)

    verify = subparsers.add_parser("verify-repository")
    verify.add_argument("--owner", default=DEFAULT_OWNER)
    verify.add_argument("--repo", default=DEFAULT_REPOSITORY)
    verify.set_defaults(func=command_verify)

    publish = subparsers.add_parser("publish-release")
    publish.add_argument("--owner", default=DEFAULT_OWNER)
    publish.add_argument("--repo", default=DEFAULT_REPOSITORY)
    publish.add_argument("--tag", required=True)
    publish.add_argument("--name", required=True)
    publish.add_argument("--notes", required=True, type=Path)
    publish.add_argument("--file", dest="files", required=True, action="append", type=Path)
    publish.add_argument("--output", required=True, type=Path)
    publish.set_defaults(func=command_publish)

    put_file = subparsers.add_parser("put-file")
    put_file.add_argument("--owner", default=DEFAULT_OWNER)
    put_file.add_argument("--repo", default=DEFAULT_REPOSITORY)
    put_file.add_argument("--path", required=True)
    put_file.add_argument("--branch", default="main")
    put_file.add_argument("--file", required=True, type=Path)
    put_file.add_argument("--message", required=True)
    put_file.set_defaults(func=command_put_file)
    return parser


def main() -> int:
    args = make_parser().parse_args()
    try:
        args.func(args)
        return 0
    except (GiteeError, OSError, ValueError) as exc:
        print(f"Gitee mirror error: {exc}", file=os.sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
