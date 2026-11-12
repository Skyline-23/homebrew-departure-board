#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENVIRONMENT="$ROOT/work/update-tools"

if [[ ! -x "$ENVIRONMENT/bin/python" ]]; then python3 -m venv "$ENVIRONMENT"; fi
"$ENVIRONMENT/bin/python" -m pip install --quiet --disable-pip-version-check -r "$ROOT/script/requirements-updates.txt"
printf '%s\n' "$ENVIRONMENT/bin/python"
