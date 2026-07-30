#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
provenance="$(cd "$(dirname "${1:?usage: publish-update-mirrors.sh <provenance> [zh-CN-notes] [en-notes]}")" && pwd)/$(basename "$1")"
notes_zh_cn_input="${2:-}"
notes_en_input="${3:-}"
cd "${root}"

bash scripts/verify-formal-artifact.sh "${provenance}"
version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["version"])' "${provenance}")"
staging="$(dirname "${provenance}")/dual-mirror-${version}"
notes_zh_cn="${notes_zh_cn_input:-$(dirname "${provenance}")/aulycShot-${version}-release-notes.zh-CN.md}"
notes_en="${notes_en_input:-$(dirname "${provenance}")/aulycShot-${version}-release-notes.en.md}"

if [[ -z "${notes_zh_cn_input}" ]]; then
  python3 scripts/release_tool.py release-notes \
    --version "${version}" --channel gitee --output "${notes_zh_cn}"
fi
if [[ -z "${notes_en_input}" ]]; then
  python3 scripts/release_tool.py release-notes \
    --version "${version}" --channel english --output "${notes_en}"
fi

bash scripts/dual-mirror-release.sh prepare \
  --provenance "${provenance}" \
  --notes-zh-cn "${notes_zh_cn}" \
  --notes-en "${notes_en}" \
  --output-dir "${staging}"
bash scripts/dual-mirror-release.sh preflight \
  --plan "${staging}/dual-mirror-plan.json"
bash scripts/dual-mirror-release.sh publish \
  --plan "${staging}/dual-mirror-plan.json" \
  --state "${staging}/dual-mirror-state.json"
bash scripts/dual-mirror-release.sh verify \
  --plan "${staging}/dual-mirror-plan.json" \
  --state "${staging}/dual-mirror-state.json"

echo "Published and verified identical public GitHub/Gitee mirrors for ${version}"
