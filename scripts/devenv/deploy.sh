#!/usr/bin/env bash
set -euo pipefail
cd "$DEVENV_ROOT"
exec nix run --no-update-lock-file .#deploy-rs -- "$@"
