#!/usr/bin/env bash
set -euo pipefail
cd "$DEVENV_ROOT"
exec bash scripts/fleet/ready.sh "$@"
