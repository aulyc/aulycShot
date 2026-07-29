#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROVENANCE="$(cd "$(dirname "${1:?usage: publish-update-mirrors.sh <provenance> [github-notes] [gitee-notes]}")" && pwd)/$(basename "$1")"
GITHUB_NOTES_INPUT="${2:-}"
GITEE_NOTES_INPUT="${3:-}"
GITHUB_MIRROR="aulyc/aulycShot-releases"
GITEE_OWNER="aulyc"
GITEE_MIRROR="aulycShot-releases"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/aulycshot-update-mirror.XXXXXX")"
trap 'rm -rf "$TEMP_ROOT"' EXIT
: "${GITEE_ACCESS_TOKEN:?GITEE_ACCESS_TOKEN is required for the Gitee release mirror}"
cd "$ROOT"

bash scripts/verify-formal-artifact.sh "$PROVENANCE"
VERSION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["version"])' "$PROVENANCE")"
DMG_NAME="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["artifacts"][0]["file"])' "$PROVENANCE")"
DMG="$(dirname "$PROVENANCE")/$DMG_NAME"
GITHUB_NOTES="${GITHUB_NOTES_INPUT:-$(dirname "$PROVENANCE")/aulycShot-$VERSION-release-notes.github.md}"
GITEE_NOTES="${GITEE_NOTES_INPUT:-$(dirname "$PROVENANCE")/aulycShot-$VERSION-release-notes.gitee.md}"
if [[ -z "$GITHUB_NOTES_INPUT" ]]; then
    python3 scripts/release_tool.py release-notes \
        --version "$VERSION" --channel github --output "$GITHUB_NOTES"
fi
if [[ -z "$GITEE_NOTES_INPUT" ]]; then
    python3 scripts/release_tool.py release-notes \
        --version "$VERSION" --channel gitee --output "$GITEE_NOTES"
fi
[[ -f "$GITHUB_NOTES" ]] || {
    echo "error: GitHub release notes are missing: $GITHUB_NOTES" >&2
    exit 1
}
[[ -f "$GITEE_NOTES" ]] || {
    echo "error: Gitee release notes are missing: $GITEE_NOTES" >&2
    exit 1
}

[[ "$(gh repo view "$GITHUB_MIRROR" --json visibility --jq .visibility)" == "PUBLIC" ]] || {
    echo "error: GitHub update mirror is missing or is not public: $GITHUB_MIRROR" >&2
    exit 1
}
python3 scripts/gitee_release.py verify-repository \
    --owner "$GITEE_OWNER" \
    --repo "$GITEE_MIRROR"

if TAG_REF="$(gh api "repos/$GITHUB_MIRROR/git/ref/tags/$VERSION" --jq '[.object.type,.object.sha] | @tsv' 2>/dev/null)"; then
    TAG_TYPE="${TAG_REF%%$'\t'*}"
    TAG_SHA="${TAG_REF#*$'\t'}"
    [[ "$TAG_TYPE" == "tag" ]] || {
        echo "error: GitHub mirror tag $VERSION is not annotated" >&2
        exit 1
    }
    [[ "$(gh api "repos/$GITHUB_MIRROR/git/tags/$TAG_SHA" --jq .tag)" == "$VERSION" ]] || {
        echo "error: GitHub mirror tag object does not match $VERSION" >&2
        exit 1
    }
else
    MIRROR_MAIN_SHA="$(gh api "repos/$GITHUB_MIRROR/git/ref/heads/main" --jq .object.sha)"
    MIRROR_TAG_SHA="$(gh api --method POST "repos/$GITHUB_MIRROR/git/tags" \
        -f tag="$VERSION" \
        -f message="aulycShot $VERSION update mirror" \
        -f object="$MIRROR_MAIN_SHA" \
        -f type=commit \
        --jq .sha)"
    gh api --method POST "repos/$GITHUB_MIRROR/git/refs" \
        -f ref="refs/tags/$VERSION" \
        -f sha="$MIRROR_TAG_SHA" >/dev/null
fi

if RELEASE_STATE="$(gh release view "$VERSION" \
    --repo "$GITHUB_MIRROR" \
    --json tagName,isDraft,isPrerelease \
    --jq '[.tagName,.isDraft,.isPrerelease] | @tsv' 2>/dev/null)"; then
    [[ "$RELEASE_STATE" == "$VERSION"$'\tfalse\tfalse' ]] || {
        echo "error: GitHub update mirror release $VERSION has conflicting metadata" >&2
        exit 1
    }
else
    gh release create "$VERSION" \
        --repo "$GITHUB_MIRROR" \
        --verify-tag \
        --title "aulycShot $VERSION" \
        --notes-file "$GITHUB_NOTES" \
        "$DMG" "$DMG.sha256" "$PROVENANCE" "$PROVENANCE.sha256"
fi

GITHUB_READBACK_DIR="$TEMP_ROOT/github-release"
mkdir -p "$GITHUB_READBACK_DIR"
gh release download "$VERSION" \
    --repo "$GITHUB_MIRROR" \
    --dir "$GITHUB_READBACK_DIR"
for EXPECTED_FILE in "$DMG" "$DMG.sha256" "$PROVENANCE" "$PROVENANCE.sha256"; do
    EXPECTED_NAME="$(basename "$EXPECTED_FILE")"
    [[ -f "$GITHUB_READBACK_DIR/$EXPECTED_NAME" ]] || {
        echo "error: GitHub update mirror is missing $EXPECTED_NAME" >&2
        exit 1
    }
    cmp -s "$EXPECTED_FILE" "$GITHUB_READBACK_DIR/$EXPECTED_NAME" || {
        echo "error: GitHub update mirror readback mismatch for $EXPECTED_NAME" >&2
        exit 1
    }
done
[[ "$(find "$GITHUB_READBACK_DIR" -type f | wc -l | tr -d ' ')" == "4" ]] || {
    echo "error: GitHub update mirror release contains unexpected assets" >&2
    exit 1
}

GITHUB_DOWNLOAD_URL="https://github.com/$GITHUB_MIRROR/releases/download/$VERSION/$DMG_NAME"
GITHUB_RELEASE_PAGE="https://github.com/$GITHUB_MIRROR/releases/tag/$VERSION"
GITEE_RESULT="$TEMP_ROOT/gitee-release.json"
python3 scripts/gitee_release.py publish-release \
    --owner "$GITEE_OWNER" \
    --repo "$GITEE_MIRROR" \
    --tag "$VERSION" \
    --name "aulycShot $VERSION" \
    --notes "$GITEE_NOTES" \
    --file "$DMG" \
    --file "$DMG.sha256" \
    --file "$PROVENANCE" \
    --file "$PROVENANCE.sha256" \
    --output "$GITEE_RESULT"
GITEE_DOWNLOAD_URL="$(python3 -c '
import json,sys
value=json.load(open(sys.argv[1], encoding="utf-8"))
name=sys.argv[2]
matches=[item["downloadURL"] for item in value["attachments"] if item["file"] == name]
assert len(matches) == 1
print(matches[0])
' "$GITEE_RESULT" "$DMG_NAME")"

MANIFEST="$TEMP_ROOT/latest.json"
python3 scripts/release_tool.py write-update-manifest \
    --provenance "$PROVENANCE" \
    --github-url "$GITHUB_DOWNLOAD_URL" \
    --gitee-url "$GITEE_DOWNLOAD_URL" \
    --release-page-url "$GITHUB_RELEASE_PAGE" \
    --output "$MANIFEST"

MANIFEST_CONTENT="$(base64 < "$MANIFEST" | tr -d '\n')"
if MANIFEST_SHA="$(gh api "repos/$GITHUB_MIRROR/contents/latest.json?ref=main" --jq .sha 2>/dev/null)"; then
    gh api --method PUT "repos/$GITHUB_MIRROR/contents/latest.json" \
        -f message="chore: publish $VERSION update manifest" \
        -f content="$MANIFEST_CONTENT" \
        -f branch=main \
        -f sha="$MANIFEST_SHA" >/dev/null
else
    gh api --method PUT "repos/$GITHUB_MIRROR/contents/latest.json" \
        -f message="chore: publish $VERSION update manifest" \
        -f content="$MANIFEST_CONTENT" \
        -f branch=main >/dev/null
fi

python3 scripts/gitee_release.py put-file \
    --owner "$GITEE_OWNER" \
    --repo "$GITEE_MIRROR" \
    --path latest.json \
    --branch main \
    --file "$MANIFEST" \
    --message "chore: publish $VERSION update manifest"

GITHUB_READBACK="$(gh api "repos/$GITHUB_MIRROR/contents/latest.json?ref=main" --jq .content | tr -d '\n')"
[[ "$GITHUB_READBACK" == "$MANIFEST_CONTENT" ]] || {
    echo "error: GitHub update manifest readback mismatch" >&2
    exit 1
}
gh release view "$VERSION" --repo "$GITHUB_MIRROR" --json tagName,isDraft,isPrerelease,url
echo "Published identical GitHub/Gitee update mirrors for $VERSION"
