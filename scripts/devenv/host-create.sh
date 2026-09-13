#!/usr/bin/env bash
set -euo pipefail
cd "${DEVENV_ROOT:?Enter the locked devenv shell}"
[[ $# == 0 ]] || { echo 'Use host:create task inputs.' >&2; exit 1; }
exec python3 scripts/fleet/scaffold.py
