#!/usr/bin/env bash
set -euo pipefail
cd "${DEVENV_ROOT:?Enter the locked devenv shell}"
bash scripts/secrets/check.sh
python3 scripts/devenv/check-tasks.py "${DEVENV_TASK_FILE:?Missing native task metadata}"
treefmt --ci
tofu fmt -check -recursive tofu
statix check .
deadnix --fail .
find scripts -name '*.sh' -print0 | xargs -0 shellcheck .envrc
python3 scripts/agents/check-guidance.py "$PWD"
bash scripts/secrets/test-check.sh
jq -e --slurpfile flake flake.lock '.nodes.nixpkgs.locked == $flake[0].nodes.nixpkgs.locked' devenv.lock >/dev/null
jq -e '.nodes.devenv.original == {owner: "cachix", repo: "devenv", type: "github"}' devenv.lock >/dev/null
packaged=$(nix eval --no-update-lock-file --raw .#packages.x86_64-linux.tailscale-tofu)
test "$(readlink -f "$(command -v tofu)")" = "$packaged/bin/tofu"
nix eval --no-update-lock-file --json .#fleet | jq 'map_values({track,revision,ready,missing,failedAssertions})'
nix eval --no-update-lock-file --json .#validation | jq '{hosts,fixtures,compositions,storageLayouts,sops,desktop,wifi,tailscale}'
nix flake check --no-update-lock-file -L
