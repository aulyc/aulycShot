#!/usr/bin/env python3
"""Release metadata and provenance helpers for aulycShot."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import plistlib
import re
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
INFO_PLIST = ROOT / "aulycShot" / "App" / "Info.plist"
EXTENSION_INFO_PLIST = ROOT / "aulycShot-share-extension" / "Info.plist"
CHANGELOG = ROOT / "CHANGELOG.md"
CHANGELOG_ZH_CN = ROOT / "CHANGELOG.zh-CN.md"
ADOPTION = ROOT / ".codex" / "standards.json"
STABLE_SEMVER = re.compile(r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$")
SEMVER = re.compile(
    r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
    r"(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$"
)
EXPECTED_ARCHITECTURES = {"arm64"}
RUNTIME_ICON_RESOURCES = (
    (Path("Resources/AppIcon.icns"), Path("Contents/Resources/AppIcon.icns")),
    (Path("design/menuBarIcon.svg"), Path("Contents/Resources/MenuBarIcon.svg")),
    (
        Path("Resources/AppIcon.icns"),
        Path("Contents/PlugIns/AulycShotShareExtension.appex/Contents/Resources/AppIcon.icns"),
    ),
)


class ReleaseError(Exception):
    pass


def run(command: list[str], cwd: Path | None = None, combine: bool = False) -> str:
    completed = subprocess.run(
        command,
        cwd=str(cwd or ROOT),
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT if combine else subprocess.PIPE,
        text=True,
    )
    if completed.returncode != 0:
        detail = (completed.stdout or completed.stderr or "").strip()
        raise ReleaseError(f"{command[0]} failed: {detail}")
    if combine:
        return completed.stdout.strip()
    return completed.stdout.strip()


def git(root: Path, *arguments: str) -> str:
    return run(["git", "-C", str(root), *arguments], cwd=root)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_json_object(path: Path, description: str) -> dict:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ReleaseError(f"invalid {description}: {exc}") from exc
    if not isinstance(value, dict):
        raise ReleaseError(f"{description} must be a JSON object")
    return value


def release_profile_identity() -> tuple[str, str]:
    adoption = load_json_object(ADOPTION, "standards adoption")
    artifacts = adoption.get("artifacts")
    if not isinstance(artifacts, list):
        raise ReleaseError("artifacts is missing from .codex/standards.json")

    matching = [
        artifact
        for artifact in artifacts
        if isinstance(artifact, dict)
        and artifact.get("type") == "macos-arm64-app"
    ]
    if len(matching) != 1:
        raise ReleaseError("expected exactly one macos-arm64-app standards artifact")

    profile = matching[0].get("profile")
    profile_version = matching[0].get("profileVersion")
    if profile != "macos-arm64-app":
        raise ReleaseError("unexpected release profile in .codex/standards.json")
    if not isinstance(profile_version, str) or not SEMVER.fullmatch(profile_version):
        raise ReleaseError("release profile version must be SemVer")
    return profile, profile_version


def read_plist(path: Path) -> dict:
    try:
        with path.open("rb") as handle:
            value = plistlib.load(handle)
    except (OSError, plistlib.InvalidFileException) as exc:
        raise ReleaseError(f"invalid plist {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise ReleaseError(f"plist root must be a dictionary: {path}")
    return value


def write_plist(path: Path, value: dict) -> None:
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{path.name}-", dir=path.parent)
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as handle:
            plistlib.dump(value, handle, sort_keys=False)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def version_identity(require_stable: bool = False) -> tuple[str, int]:
    plist = read_plist(INFO_PLIST)
    version = plist.get("CFBundleShortVersionString")
    raw_build = plist.get("CFBundleVersion")
    if not isinstance(version, str) or not SEMVER.fullmatch(version):
        raise ReleaseError("CFBundleShortVersionString must be SemVer")
    if require_stable and not STABLE_SEMVER.fullmatch(version):
        raise ReleaseError("formal release version must be stable SemVer")
    try:
        build = int(raw_build)
    except (TypeError, ValueError) as exc:
        raise ReleaseError("CFBundleVersion must be a positive integer") from exc
    if build <= 0 or str(build) != str(raw_build):
        raise ReleaseError("CFBundleVersion must be a canonical positive integer")
    if plist.get("CFBundleIdentifier") != "com.aulyc.aulycshot":
        raise ReleaseError("unexpected application bundle identifier")
    if plist.get("LSMinimumSystemVersion") != "14.0":
        raise ReleaseError("unexpected minimum macOS version")
    return version, build


def changelog_has_release(path: Path, version: str) -> bool:
    text = path.read_text(encoding="utf-8")
    return re.search(rf"^## \[{re.escape(version)}\] - \d{{4}}-\d{{2}}-\d{{2}}$", text, re.M) is not None


def command_version_check(args: argparse.Namespace) -> None:
    version, build = version_identity(require_stable=args.release)
    extension = read_plist(EXTENSION_INFO_PLIST)
    if extension.get("CFBundleIdentifier") != "com.aulyc.aulycshot.shareextension":
        raise ReleaseError("unexpected share extension bundle identifier")
    if args.release:
        for path in (CHANGELOG, CHANGELOG_ZH_CN):
            if not changelog_has_release(path, version):
                raise ReleaseError(f"{path.name} has no dated heading for {version}")
    print(f"version identity valid: {version} build {build}")


def version_tuple(value: str) -> tuple[int, int, int]:
    match = STABLE_SEMVER.fullmatch(value)
    if match is None:
        raise ReleaseError("target version must be stable SemVer")
    return tuple(int(part) for part in match.groups())


def prepared_changelog(path: Path, target_version: str) -> str:
    text = path.read_text(encoding="utf-8")
    marker = "## [Unreleased]"
    if not text.startswith("# ") or marker not in text:
        raise ReleaseError(f"{path.name} has no Unreleased heading")
    marker_end = text.index(marker) + len(marker)
    body = text[marker_end:].lstrip("\n")
    first_heading = re.search(r"^## \[", body, re.M)
    unreleased_body = body[: first_heading.start()] if first_heading else body
    if not unreleased_body.strip():
        raise ReleaseError(f"{path.name} Unreleased section is empty")
    date = dt.date.today().isoformat()
    return text[:marker_end] + f"\n\n## [{target_version}] - {date}\n\n" + body


def command_prepare(args: argparse.Namespace) -> None:
    target_version = args.version
    target_build = args.build
    current_version, current_build = version_identity()
    if version_tuple(target_version) <= version_tuple(current_version):
        raise ReleaseError("target version must be greater than the current version")
    if target_build <= current_build:
        raise ReleaseError("target build must be greater than the current build")
    updated_changelog = prepared_changelog(CHANGELOG, target_version)
    updated_changelog_zh_cn = prepared_changelog(CHANGELOG_ZH_CN, target_version)
    plist = read_plist(INFO_PLIST)
    plist["CFBundleShortVersionString"] = target_version
    plist["CFBundleVersion"] = str(target_build)
    write_plist(INFO_PLIST, plist)
    CHANGELOG.write_text(updated_changelog, encoding="utf-8")
    CHANGELOG_ZH_CN.write_text(updated_changelog_zh_cn, encoding="utf-8")
    print(f"prepared release metadata: {target_version} build {target_build}")


def codesign_has_runtime(output: str) -> bool:
    return re.search(r"^CodeDirectory .*\bflags=.*\(runtime\)", output, re.M) is not None


def verify_runtime_resources(app: Path) -> None:
    for source_relative, bundled_relative in RUNTIME_ICON_RESOURCES:
        source = ROOT / source_relative
        bundled = app / bundled_relative
        if not source.is_file():
            raise ReleaseError(f"generated icon source is missing: {source}")
        if not bundled.is_file():
            raise ReleaseError(f"runtime icon resource is missing: {bundled}")
        if sha256(source) != sha256(bundled):
            raise ReleaseError(
                f"runtime icon resource does not match generated source: {bundled}"
            )


def parse_codesign(app: Path) -> tuple[str, str, bool]:
    output = run(["codesign", "-dv", "--verbose=4", str(app)], combine=True)
    team_match = re.search(r"^TeamIdentifier=(.+)$", output, re.M)
    authority_match = re.search(r"^Authority=(.+)$", output, re.M)
    runtime = codesign_has_runtime(output)
    if team_match is None or authority_match is None:
        raise ReleaseError("Developer ID signature identity is incomplete")
    authority = authority_match.group(1).strip()
    if not authority.startswith("Developer ID Application:"):
        raise ReleaseError("application is not signed with Developer ID Application")
    return team_match.group(1).strip(), authority, runtime


def app_identity(app: Path) -> dict:
    info = read_plist(app / "Contents" / "Info.plist")
    executable = app / "Contents" / "MacOS" / "aulycShot"
    extension = app / "Contents" / "PlugIns" / "AulycShotShareExtension.appex"
    extension_executable = extension / "Contents" / "MacOS" / "AulycShotShareExtension"
    for required in (executable, extension, extension_executable):
        if not required.exists():
            raise ReleaseError(f"required bundle item is missing: {required}")
    verify_runtime_resources(app)
    run(["codesign", "--verify", "--deep", "--strict", "--verbose=2", str(app)], combine=True)
    run(["codesign", "--verify", "--strict", "--verbose=2", str(extension)], combine=True)
    architectures = set(run(["lipo", "-archs", str(executable)]).split())
    extension_architectures = set(run(["lipo", "-archs", str(extension_executable)]).split())
    if architectures != EXPECTED_ARCHITECTURES:
        raise ReleaseError(f"unexpected app architectures: {sorted(architectures)}")
    if extension_architectures != EXPECTED_ARCHITECTURES:
        raise ReleaseError(f"unexpected share extension architectures: {sorted(extension_architectures)}")
    team, authority, runtime = parse_codesign(app)
    extension_team, extension_authority, extension_runtime = parse_codesign(extension)
    if team != extension_team or authority != extension_authority:
        raise ReleaseError("app and share extension signing identities differ")
    if not runtime or not extension_runtime:
        raise ReleaseError("Hardened Runtime is missing from the app or share extension")
    return {
        "version": str(info.get("CFBundleShortVersionString")),
        "build": int(info.get("CFBundleVersion")),
        "bundleIdentifier": info.get("CFBundleIdentifier"),
        "minimumSystemVersion": info.get("LSMinimumSystemVersion"),
        "commit": info.get("AulycShotGitCommit"),
        "releaseChannel": info.get("AulycShotReleaseChannel"),
        "tag": info.get("AulycShotReleaseTag"),
        "dirty": info.get("AulycShotBuildDirty"),
        "architectures": sorted(architectures),
        "teamIdentifier": team,
        "signatureAuthority": authority,
        "hardenedRuntime": True,
        "executableSha256": sha256(executable),
    }


def atomic_write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{path.name}-", suffix=".tmp", dir=path.parent)
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


def command_write_provenance(args: argparse.Namespace) -> None:
    source_root = args.source_root.resolve()
    app = args.app.resolve()
    dmg = args.dmg.resolve()
    output = args.output.resolve()
    if not dmg.is_file() or not app.is_dir():
        raise ReleaseError("formal app or DMG is missing")
    if git(source_root, "status", "--porcelain=v1", "--untracked-files=all"):
        raise ReleaseError("exact-tag source is dirty")
    tag = args.tag
    if not STABLE_SEMVER.fullmatch(tag):
        raise ReleaseError("formal tag must be stable SemVer")
    commit = git(source_root, "rev-parse", "HEAD")
    git(source_root, "rev-parse", "--verify", f"refs/tags/{tag}^{{tag}}")
    if git(source_root, "rev-list", "-n", "1", f"refs/tags/{tag}") != commit:
        raise ReleaseError("annotated tag does not point to the exact source commit")
    identity = app_identity(app)
    if identity["version"] != tag or identity["tag"] != tag:
        raise ReleaseError("app version or release tag does not match the formal tag")
    if identity["commit"] != commit or identity["releaseChannel"] != "formal" or identity["dirty"] is not False:
        raise ReleaseError("embedded formal source identity is invalid")
    release_profile, release_profile_version = release_profile_identity()
    provenance = {
        "schemaVersion": 1,
        "project": "aulycShot",
        "releaseProfile": release_profile,
        "releaseProfileVersion": release_profile_version,
        "releaseChannel": "formal",
        "version": identity["version"],
        "buildNumber": identity["build"],
        "tag": tag,
        "commit": commit,
        "dirty": False,
        "architecture": "arm64",
        "architectures": identity["architectures"],
        "bundleIdentifier": identity["bundleIdentifier"],
        "teamIdentifier": identity["teamIdentifier"],
        "minimumSystemVersion": identity["minimumSystemVersion"],
        "signatureType": "developer-id",
        "signatureAuthority": identity["signatureAuthority"],
        "hardenedRuntime": True,
        "notarized": True,
        "notarizationSubmissionId": args.submission_id,
        "stapled": True,
        "gatekeeperAccepted": True,
        "appExecutableSha256": identity["executableSha256"],
        "artifacts": [{"file": dmg.name, "sha256": sha256(dmg)}],
        "builtAt": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    }
    atomic_write_json(output, provenance)
    print(output)


def load_provenance(path: Path) -> dict:
    return load_json_object(path, "release provenance")


def validate_provenance(path: Path) -> tuple[dict, Path]:
    value = load_provenance(path)
    release_profile, release_profile_version = release_profile_identity()
    required = {
        "releaseProfile": release_profile,
        "releaseProfileVersion": release_profile_version,
        "releaseChannel": "formal",
        "dirty": False,
        "architecture": "arm64",
        "architectures": ["arm64"],
        "bundleIdentifier": "com.aulyc.aulycshot",
        "hardenedRuntime": True,
        "notarized": True,
        "stapled": True,
        "gatekeeperAccepted": True,
    }
    for field, expected in required.items():
        if value.get(field) != expected:
            raise ReleaseError(f"release provenance field {field} is invalid")
    version = value.get("version")
    if not isinstance(version, str) or not STABLE_SEMVER.fullmatch(version) or value.get("tag") != version:
        raise ReleaseError("release provenance version and tag are invalid")
    if not isinstance(value.get("buildNumber"), int) or value["buildNumber"] <= 0:
        raise ReleaseError("release provenance build number is invalid")
    commit = value.get("commit")
    if not isinstance(commit, str) or re.fullmatch(r"[0-9a-f]{40}", commit) is None:
        raise ReleaseError("release provenance commit is invalid")
    artifacts = value.get("artifacts")
    if not isinstance(artifacts, list) or len(artifacts) != 1:
        raise ReleaseError("release provenance must contain exactly one DMG artifact")
    artifact = artifacts[0]
    if not isinstance(artifact, dict) or not isinstance(artifact.get("file"), str):
        raise ReleaseError("release provenance artifact record is invalid")
    dmg = path.parent / artifact["file"]
    if not dmg.is_file() or sha256(dmg) != artifact.get("sha256"):
        raise ReleaseError("DMG SHA-256 does not match release provenance")
    return value, dmg


def command_verify_provenance(args: argparse.Namespace) -> None:
    value, dmg = validate_provenance(args.provenance.resolve())
    print(f"release provenance valid: {value['version']} build {value['buildNumber']} {dmg.name}")


def command_verify_app(args: argparse.Namespace) -> None:
    provenance, _ = validate_provenance(args.provenance.resolve())
    identity = app_identity(args.app.resolve())
    comparisons = {
        "version": provenance["version"],
        "build": provenance["buildNumber"],
        "bundleIdentifier": provenance["bundleIdentifier"],
        "commit": provenance["commit"],
        "releaseChannel": "formal",
        "tag": provenance["tag"],
        "dirty": False,
        "architectures": provenance["architectures"],
        "teamIdentifier": provenance["teamIdentifier"],
        "hardenedRuntime": True,
        "executableSha256": provenance["appExecutableSha256"],
    }
    for field, expected in comparisons.items():
        if identity.get(field) != expected:
            raise ReleaseError(f"installed app field {field} does not match release provenance")
    print(f"app identity valid: {args.app} {identity['version']} build {identity['build']}")


def command_verify_runtime_resources(args: argparse.Namespace) -> None:
    verify_runtime_resources(args.app.resolve())
    print(f"runtime resources valid: {args.app}")


def extract_release_notes(path: Path, version: str) -> str:
    text = path.read_text(encoding="utf-8")
    start_match = re.search(rf"^## \[{re.escape(version)}\] - \d{{4}}-\d{{2}}-\d{{2}}\n", text, re.M)
    if start_match is None:
        raise ReleaseError(f"{path.name} release notes heading is missing")
    rest = text[start_match.end() :]
    end_match = re.search(r"^## \[", rest, re.M)
    return (rest[: end_match.start()] if end_match else rest).strip() + "\n"


def command_release_notes(args: argparse.Namespace) -> None:
    english = extract_release_notes(CHANGELOG, args.version)
    chinese = extract_release_notes(CHANGELOG_ZH_CN, args.version)
    if args.channel == "github":
        notes = f"## 中文\n\n{chinese}\n---\n\n## English\n\n{english}"
    elif args.channel == "gitee":
        notes = chinese
    else:
        notes = english
    args.output.write_text(notes, encoding="utf-8")
    print(args.output)


def command_refresh_standards(_: argparse.Namespace) -> None:
    adoption = load_provenance(ADOPTION)
    tracked = adoption.get("trackedFiles")
    if not isinstance(tracked, list):
        raise ReleaseError("trackedFiles is missing from .codex/standards.json")
    for item in tracked:
        relative = item.get("path")
        target = ROOT / relative
        if not isinstance(relative, str) or not target.is_file():
            raise ReleaseError(f"tracked release file is missing: {relative}")
        item["sha256"] = sha256(target)
    atomic_write_json(ADOPTION, adoption)
    print(f"refreshed {len(tracked)} standards hashes")


def make_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    version_check = subparsers.add_parser("version-check")
    version_check.add_argument("--release", action="store_true")
    version_check.set_defaults(func=command_version_check)

    prepare = subparsers.add_parser("prepare")
    prepare.add_argument("--version", required=True)
    prepare.add_argument("--build", required=True, type=int)
    prepare.set_defaults(func=command_prepare)

    provenance = subparsers.add_parser("write-provenance")
    provenance.add_argument("--source-root", required=True, type=Path)
    provenance.add_argument("--app", required=True, type=Path)
    provenance.add_argument("--dmg", required=True, type=Path)
    provenance.add_argument("--output", required=True, type=Path)
    provenance.add_argument("--tag", required=True)
    provenance.add_argument("--submission-id", required=True)
    provenance.set_defaults(func=command_write_provenance)

    verify = subparsers.add_parser("verify-provenance")
    verify.add_argument("--provenance", required=True, type=Path)
    verify.set_defaults(func=command_verify_provenance)

    verify_app = subparsers.add_parser("verify-app")
    verify_app.add_argument("--provenance", required=True, type=Path)
    verify_app.add_argument("--app", required=True, type=Path)
    verify_app.set_defaults(func=command_verify_app)

    verify_resources = subparsers.add_parser("verify-runtime-resources")
    verify_resources.add_argument("--app", required=True, type=Path)
    verify_resources.set_defaults(func=command_verify_runtime_resources)

    release_notes = subparsers.add_parser("release-notes")
    release_notes.add_argument("--version", required=True)
    release_notes.add_argument(
        "--channel",
        required=True,
        choices=("github", "gitee", "english"),
    )
    release_notes.add_argument("--output", required=True, type=Path)
    release_notes.set_defaults(func=command_release_notes)

    refresh = subparsers.add_parser("refresh-standards")
    refresh.set_defaults(func=command_refresh_standards)
    return parser


def main() -> int:
    args = make_parser().parse_args()
    try:
        args.func(args)
        return 0
    except (ReleaseError, OSError, ValueError) as exc:
        print(f"release error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
