#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
standards_root="${STANDARDS_ROOT:-${AULYC_STANDARDS_ROOT:-/Users/crp/Projects/Codex 开发规范}}"
provenance="$(cd "$(dirname "${1:?usage: publish-release.sh <provenance>}")" && pwd)/$(basename "$1")"
cd "${root}"

bash scripts/verify-formal-artifact.sh "${provenance}"
version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["version"])' "${provenance}")"

python3 "${standards_root}/scripts/formal_release_git.py" push \
  --path "${root}" --tag "${version}" --provenance "${provenance}"
provenance_sha="$(shasum -a 256 "${provenance}" | awk '{print $1}')"
printf '%s  %s\n' "${provenance_sha}" "$(basename "${provenance}")" \
  > "${provenance}.sha256"
python3 "${standards_root}/scripts/formal_release_git.py" verify \
  --path "${root}" --tag "${version}" --provenance "${provenance}"

notes_zh_cn="$(dirname "${provenance}")/aulycShot-${version}-release-notes.zh-CN.md"
notes_en="$(dirname "${provenance}")/aulycShot-${version}-release-notes.en.md"
python3 scripts/release_tool.py release-notes \
  --version "${version}" --channel gitee --output "${notes_zh_cn}"
python3 scripts/release_tool.py release-notes \
  --version "${version}" --channel english --output "${notes_en}"

AULYC_STANDARDS_ROOT="${standards_root}" \
  bash scripts/publish-update-mirrors.sh \
    "${provenance}" "${notes_zh_cn}" "${notes_en}"
echo "Published the public source refs and verified both public release channels for ${version}"
