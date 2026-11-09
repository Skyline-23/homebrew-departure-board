#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILES=("$ROOT"/Sources/*.{h,m} "$ROOT"/Sources/Airports/*.{h,m} \
       "$ROOT"/Sources/Airports/Adapters/*.m "$ROOT"/Tests/*.m)

if [[ "${1:-}" == --check ]]; then
  xcrun clang-format --dry-run --Werror "${FILES[@]}"
  xcrun swift-format lint --strict --configuration "$ROOT/.swift-format" "$ROOT/Tests/InstalledApplication.swift"
  python3 "$ROOT/script/function-spacing.py"
else
  xcrun clang-format -i "${FILES[@]}"
  xcrun swift-format format --in-place --configuration "$ROOT/.swift-format" "$ROOT/Tests/InstalledApplication.swift"
  python3 "$ROOT/script/function-spacing.py" --fix
fi
