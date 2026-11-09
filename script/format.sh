#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILES=("$ROOT"/Sources/*.{h,m} "$ROOT"/Sources/Airports/*.{h,m} \
       "$ROOT"/Sources/Airports/Adapters/*.m "$ROOT"/Tests/*.m)
if [[ "${1:-}" == --check ]]; then
  xcrun clang-format --dry-run --Werror "${FILES[@]}"
else
  xcrun clang-format -i "${FILES[@]}"
fi
