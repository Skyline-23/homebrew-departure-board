#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_BUNDLES="$PROJECT_ROOT/work/Build.noindex/Bundles"
DISK_IMAGE="${1:-}"
RESULT_PREFIX="notarization"

staple_with_retry() {
  local target="$1" attempt result

  for attempt in 1 2 3; do
    if xcrun stapler staple "$target" && xcrun stapler validate "$target"; then
      return 0
    else
      result=$?
    fi

    # EX_NOHOST includes transient failures from Apple's ticket service.
    if [[ "$result" != 68 || "$attempt" == 3 ]]; then return "$result"; fi
    printf 'Ticket service unavailable; retrying in %s seconds.\n' "$((attempt * 5))" >&2
    sleep "$((attempt * 5))"
  done
}

if [[ -n "$DISK_IMAGE" ]]; then
  [[ "$DISK_IMAGE" == *.dmg && -f "$DISK_IMAGE" ]] || { echo 'Expected an existing DMG.' >&2; exit 1; }
  RESULT_PREFIX="notarization-dmg"
fi
: "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID}"
TEMP_ROOT="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/departure-notarize.XXXXXX")"
trap 'rm -rf "$TEMP_ROOT"' EXIT
BUNDLES="$TEMP_ROOT/Bundles"
mkdir -p "$BUNDLES"

# Synced folders can add FinderInfo after signing. Submit clean copies outside
# that folder, just as packaging does, without changing the signed contents.

for name in 'Departure Board.app' 'Departure Board.saver'; do
  ditto --noextattr --norsrc "$SOURCE_BUNDLES/$name" "$BUNDLES/$name"
done

for bundle in "$BUNDLES/Departure Board.app" "$BUNDLES/Departure Board.saver"; do
  codesign --verify --strict "$bundle"
  METADATA="$(codesign -dv --verbose=4 "$bundle" 2>&1)"

  if ! grep -q '^Authority=Developer ID Application:' <<< "$METADATA" || \
     ! grep -q "^TeamIdentifier=$APPLE_TEAM_ID$" <<< "$METADATA" || \
     ! grep -q '^Timestamp=' <<< "$METADATA" || \
     ! grep -q 'flags=.*(runtime)' <<< "$METADATA"; then
    printf 'Notarization requires timestamped Developer ID signatures with hardened runtime from the configured team.\n' >&2
    exit 1
  fi
done

AUTH=()

if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
  AUTH=(--keychain-profile "$NOTARY_KEYCHAIN_PROFILE")
else
  : "${APP_STORE_CONNECT_KEY_P8_BASE64:?Set APP_STORE_CONNECT_KEY_P8_BASE64}"
  : "${APP_STORE_CONNECT_KEY_ID:?Set APP_STORE_CONNECT_KEY_ID}"
  KEY_FILE="$TEMP_ROOT/AuthKey.p8"
  printf '%s' "$APP_STORE_CONNECT_KEY_P8_BASE64" | base64 --decode > "$KEY_FILE"
  chmod 600 "$KEY_FILE"
  AUTH=(--key "$KEY_FILE" --key-id "$APP_STORE_CONNECT_KEY_ID")

  if [[ -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then AUTH+=(--issuer "$APP_STORE_CONNECT_ISSUER_ID"); fi
fi

# Both executables are scanned in the same submission; staple each bundle afterward.
SUBMISSION="$DISK_IMAGE"

if [[ -z "$SUBMISSION" ]]; then
  SUBMISSION="$TEMP_ROOT/submission.zip"
  COPYFILE_DISABLE=1 ditto -c -k --norsrc --noextattr --keepParent "$BUNDLES" "$SUBMISSION"
fi
set +e
xcrun notarytool submit "$SUBMISSION" "${AUTH[@]}" --wait --timeout 20m \
  --output-format json > "$TEMP_ROOT/result.json"
SUBMIT_STATUS=$?
set -e
STATUS="$(python3 - "$TEMP_ROOT/result.json" <<'PYRESULT'
import json,sys
try:
    print(json.load(open(sys.argv[1])).get('status','Unknown'))
except (ValueError,OSError):
    print('Unknown')
PYRESULT
)"
mkdir -p "$PROJECT_ROOT/work"
rm -f "$PROJECT_ROOT/work/$RESULT_PREFIX-log.json"
cp "$TEMP_ROOT/result.json" "$PROJECT_ROOT/work/$RESULT_PREFIX-result.json"
SUBMISSION_ID="$(python3 - "$TEMP_ROOT/result.json" <<'PYID'
import json,sys
try:
    print(json.load(open(sys.argv[1])).get('id',''))
except (ValueError,OSError):
    pass
PYID
)"

if [[ -n "$SUBMISSION_ID" ]]; then
  xcrun notarytool log "$SUBMISSION_ID" "${AUTH[@]}" \
    "$PROJECT_ROOT/work/$RESULT_PREFIX-log.json" || true
fi

if [[ "$SUBMIT_STATUS" != 0 || "$STATUS" != Accepted ]]; then
  python3 - "$TEMP_ROOT/result.json" <<'PY'
import json,sys
try:
    result=json.load(open(sys.argv[1]))
except (ValueError,OSError):
    result={}
print('Notarization did not succeed:',result.get('status','Unknown'),result.get('id',''))
PY

  if [[ -f "$PROJECT_ROOT/work/$RESULT_PREFIX-log.json" ]]; then
    cat "$PROJECT_ROOT/work/$RESULT_PREFIX-log.json" >&2
  fi
  exit 1
fi

if [[ -n "$DISK_IMAGE" ]]; then
  staple_with_retry "$DISK_IMAGE"
  spctl --assess --type open --context context:primary-signature --verbose=4 "$DISK_IMAGE"
  printf 'Disk image notarization accepted.\n'
  exit 0
fi

for bundle in "$BUNDLES/Departure Board.app" "$BUNDLES/Departure Board.saver"; do
  staple_with_retry "$bundle"
done
spctl --assess --type execute --verbose=4 "$BUNDLES/Departure Board.app"

for name in 'Departure Board.app' 'Departure Board.saver'; do
  rm -rf "$SOURCE_BUNDLES/$name"
  ditto --noextattr --norsrc "$BUNDLES/$name" "$SOURCE_BUNDLES/$name"
done
printf 'Notarization accepted; tickets attached to both bundles.\n'
