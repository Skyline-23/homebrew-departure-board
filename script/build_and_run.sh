#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-run}"
pkill -x DepartureBoard >/dev/null 2>&1 || true
"$PROJECT_ROOT/script/build.sh"
APP="$PROJECT_ROOT/outputs/DepartureBoard/dist/Departure Board.app"
case "$MODE" in
  run) open -n "$APP" ;;
  --verify) open -n "$APP"; sleep 1; pgrep -x DepartureBoard >/dev/null ;;
  --debug) lldb -- "$APP/Contents/MacOS/DepartureBoard" ;;
  --logs|--telemetry) open -n "$APP"; log stream --style compact --predicate 'process == "DepartureBoard"' ;;
  *) printf 'Usage: %s [run|--verify|--debug|--logs|--telemetry]\n' "$0" >&2; exit 2 ;;
esac
