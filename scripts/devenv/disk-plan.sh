#!/usr/bin/env bash
set -euo pipefail
cd "$DEVENV_ROOT"
[[ $# == 1 ]] || { echo 'Usage: disk-plan HOST' >&2; exit 1; }
bash scripts/fleet/ready.sh "$1" disk-plan
exec nix build --no-update-lock-file --out-link "result-disko-$1" ".#nixosConfigurations.$1.config.system.build.diskoScript"
