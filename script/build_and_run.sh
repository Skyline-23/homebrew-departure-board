#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-run}"
case "$MODE" in
  run|--verify|--debug) "$PROJECT_ROOT/script/build.sh" ;;
  --logs|--telemetry) ;;
  *) printf 'Usage: %s [run|--verify|--debug|--logs|--telemetry]\n' "$0" >&2; exit 2 ;;
esac
APP="$PROJECT_ROOT/work/Build.noindex/Bundles/Departure Board.app"
case "$MODE" in
  run) open -n "$APP" ;;
  --verify) "$PROJECT_ROOT/script/validate.sh" ;;
  --debug) lldb -- "$APP/Contents/MacOS/DepartureBoard" ;;
  --logs|--telemetry) log stream --style compact --predicate 'process == "DepartureBoard"' ;;
esac
