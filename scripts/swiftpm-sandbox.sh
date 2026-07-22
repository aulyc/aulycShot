#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: scripts/swiftpm-sandbox.sh <build|test|run|package> [arguments...]

Examples:
  scripts/swiftpm-sandbox.sh build
  scripts/swiftpm-sandbox.sh test --filter ExampleTests
  scripts/swiftpm-sandbox.sh package resolve
EOF
}

if [[ $# -lt 1 ]]; then
  usage
  exit 64
fi

swift_subcommand=$1
shift

case "$swift_subcommand" in
  build|test|run|package)
    ;;
  *)
    echo "Unsupported SwiftPM subcommand: $swift_subcommand" >&2
    usage
    exit 64
    ;;
esac

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
project_root=$(git -C "$script_dir" rev-parse --show-toplevel)

if [[ ! -f "$project_root/Package.swift" ]]; then
  echo "Package.swift not found at repository root: $project_root" >&2
  exit 66
fi

cache_root="$project_root/.cache/swiftpm"
module_cache="$cache_root/module-cache"
package_cache="$cache_root/cache"
mkdir -p "$module_cache" "$package_cache"

export SWIFTPM_MODULECACHE_OVERRIDE="$module_cache"

swift_arguments=(
  "$swift_subcommand"
  --disable-sandbox
  --cache-path "$package_cache"
)

# Keep user-level SwiftPM configuration and security directories by default.
# Projects with private registries may opt in to CI-provisioned paths without
# changing the public-dependency default or storing credentials in the repo.
if [[ -n "${SWIFTPM_SANDBOX_CONFIG_PATH:-}" ]]; then
  swift_arguments+=(--config-path "$SWIFTPM_SANDBOX_CONFIG_PATH")
fi
if [[ -n "${SWIFTPM_SANDBOX_SECURITY_PATH:-}" ]]; then
  swift_arguments+=(--security-path "$SWIFTPM_SANDBOX_SECURITY_PATH")
fi

swift_arguments+=("$@")
exec swift "${swift_arguments[@]}"
