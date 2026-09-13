#!/usr/bin/env bash
set -euo pipefail
cd "$DEVENV_ROOT"
[[ $# == 1 ]] || { echo 'Usage: disk-plan HOST' >&2; exit 1; }
bash scripts/fleet/ready.sh "$1" disk-plan
nix build --no-update-lock-file --out-link "result-disko-$1" ".#nixosConfigurations.$1.config.system.build.diskoScript"
printf 'Read the entire generated plan before using its SHA-256 as host:install planHash:\n'
sha256sum "result-disko-$1"
