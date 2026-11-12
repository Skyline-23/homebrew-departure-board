#!/bin/bash
set -euo pipefail

# Homebrew's build sandbox cannot access the user's signing identities. When a
# local identity is available, sign after installation so Keychain approvals
# survive updates. Machines without one keep the normal ad-hoc build.
INSTALLATION_ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
IDENTITIES="$(security find-identity -v -p codesigning)"
LOCAL_IDENTITY="$(printf '%s\n' "$IDENTITIES" | awk '/Developer ID Application:/ { print $2; exit }')"

if [[ -z "$LOCAL_IDENTITY" ]]; then
  LOCAL_IDENTITY="$(printf '%s\n' "$IDENTITIES" | awk '/Apple Development:/ { print $2; exit }')"
fi
[[ -n "$LOCAL_IDENTITY" ]] || exit 0

for bundle in "$INSTALLATION_ROOT/Departure Board.app" "$INSTALLATION_ROOT/Departure Board.saver"; do
  # Re-signing a notarized download would invalidate its ticket.

  if codesign --verify --strict "$bundle" 2>/dev/null; then
    SIGNATURE="$(codesign -dvv "$bundle" 2>&1)"

    if [[ "$SIGNATURE" == *'Authority=Developer ID Application:'* ]]; then
      continue
    fi
  fi

  if codesign --verify --strict --test-requirement "=certificate leaf = H\"$LOCAL_IDENTITY\"" "$bundle" 2>/dev/null; then
    continue
  fi
  FRAMEWORK="$bundle/Contents/Frameworks/Sparkle.framework/Versions/B"

  if [[ -d "$FRAMEWORK" ]]; then

    for component in "$FRAMEWORK/XPCServices/Installer.xpc" "$FRAMEWORK/XPCServices/Downloader.xpc" \
        "$FRAMEWORK/Autoupdate" "$FRAMEWORK/Updater.app" "$bundle/Contents/Frameworks/Sparkle.framework" \
        "$bundle/Contents/Resources/Departure Board.saver"; do
      codesign --force --sign "$LOCAL_IDENTITY" --options runtime --timestamp "$component"
    done
  fi
  codesign --force --sign "$LOCAL_IDENTITY" --options runtime --timestamp "$bundle"
  codesign --verify --strict "$bundle"
done
