#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
./script/format.sh --check
xcrun swiftc -typecheck Tests/InstalledApplication.swift
REPORT="$(mktemp "${TMPDIR:-/tmp}/departure-lint.XXXXXX")"
trap 'rm -f "$REPORT"' EXIT
swiftlint lint --strict --config .swiftlint.yml 2>&1 | tee "$REPORT"
if grep -q '^warning:' "$REPORT"; then
  echo 'SwiftLint configuration warnings are treated as errors.' >&2
  exit 1
fi
