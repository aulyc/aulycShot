SHELL := /bin/bash

STANDARDS_ROOT ?= /Users/crp/Projects/Codex 开发规范
RELEASE_PROVENANCE ?=

.PHONY: check test verify version-check version-test standards-check release-check prepare-formal-release release-tag release-formal verify-artifact install-release verify-installed publish-release refresh-standards

check:
	bash scripts/compile-check.sh

test:
	swift test

verify:
	bash scripts/rebuild-and-open.sh

version-check:
	python3 scripts/release_tool.py version-check

version-test:
	PYTHONPYCACHEPREFIX=/tmp/aulycShot-pycache python3 -m unittest discover -s Tests -p 'test_*.py'

standards-check:
	python3 "$(STANDARDS_ROOT)/scripts/standards_check.py" project --path "$(CURDIR)" --strict

release-check:
	STANDARDS_ROOT="$(STANDARDS_ROOT)" bash scripts/release-check.sh

prepare-formal-release:
	@test -n "$(TARGET_VERSION)" || { echo "TARGET_VERSION is required" >&2; exit 64; }
	@test -n "$(TARGET_BUILD)" || { echo "TARGET_BUILD is required" >&2; exit 64; }
	STANDARDS_ROOT="$(STANDARDS_ROOT)" bash scripts/prepare-formal-release.sh "$(TARGET_VERSION)" "$(TARGET_BUILD)"

release-tag:
	STANDARDS_ROOT="$(STANDARDS_ROOT)" bash scripts/create-release-tag.sh

release-formal:
	@test -n "$(DEVELOPER_ID_APPLICATION)" || { echo "DEVELOPER_ID_APPLICATION is required" >&2; exit 64; }
	@test -n "$(NOTARY_PROFILE)" || { echo "NOTARY_PROFILE is required" >&2; exit 64; }
	DEVELOPER_ID_APPLICATION="$(DEVELOPER_ID_APPLICATION)" NOTARY_PROFILE="$(NOTARY_PROFILE)" \
		bash scripts/formal-release.sh

verify-artifact:
	@test -n "$(RELEASE_PROVENANCE)" || { echo "RELEASE_PROVENANCE is required" >&2; exit 64; }
	bash scripts/verify-formal-artifact.sh "$(RELEASE_PROVENANCE)"

install-release:
	@test -n "$(RELEASE_PROVENANCE)" || { echo "RELEASE_PROVENANCE is required" >&2; exit 64; }
	bash scripts/install-release.sh "$(RELEASE_PROVENANCE)"

verify-installed:
	@test -n "$(RELEASE_PROVENANCE)" || { echo "RELEASE_PROVENANCE is required" >&2; exit 64; }
	bash scripts/verify-installed.sh "$(RELEASE_PROVENANCE)"

publish-release:
	@test -n "$(RELEASE_PROVENANCE)" || { echo "RELEASE_PROVENANCE is required" >&2; exit 64; }
	STANDARDS_ROOT="$(STANDARDS_ROOT)" bash scripts/publish-release.sh "$(RELEASE_PROVENANCE)"

refresh-standards:
	python3 scripts/release_tool.py refresh-standards
