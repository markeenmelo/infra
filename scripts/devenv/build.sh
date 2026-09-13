#!/usr/bin/env bash
set -euo pipefail
cd "$DEVENV_ROOT"
[[ $# == 1 ]] || { echo 'Usage: build HOST' >&2; exit 1; }
bash scripts/fleet/ready.sh "$1"
exec nix build --no-update-lock-file ".#nixosConfigurations.$1.config.system.build.toplevel"
