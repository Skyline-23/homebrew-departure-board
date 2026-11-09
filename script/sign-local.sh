#!/bin/bash
set -euo pipefail

# Homebrew's build sandbox cannot access the user's signing identities. When a
# local identity is available, sign after installation so Keychain approvals
# survive updates. Machines without one keep the normal ad-hoc build.
INSTALLATION_ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
LOCAL_IDENTITY="$(security find-identity -v -p codesigning | awk '/Developer ID Application:|Apple Development:/ { print $2; exit }')"
[[ -n "$LOCAL_IDENTITY" ]] || exit 0

for bundle in "$INSTALLATION_ROOT/Departure Board.app" "$INSTALLATION_ROOT/Departure Board.saver"; do
  if codesign --verify --strict --test-requirement "=certificate leaf = H\"$LOCAL_IDENTITY\"" "$bundle" 2>/dev/null; then
    continue
  fi
  codesign --force --sign "$LOCAL_IDENTITY" --options runtime "$bundle"
  codesign --verify --strict "$bundle"
done
