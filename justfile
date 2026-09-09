set shell := ["bash", "-euo", "pipefail", "-c"]
set positional-arguments

default:
    @just --list

fmt:
    nix fmt --no-update-lock-file

# pkgs.nixfmt-tree provides treefmt with a generated configuration.
format-check:
    treefmt --ci

lint:
    statix check .
    deadnix --fail .
    shellcheck scripts/*.sh

secret-check:
    bash scripts/check-secrets.sh

secret-check-tests:
    bash scripts/test-secret-check.sh

evaluate:
    nix eval --no-update-lock-file --json .#validation | jq '{hosts: (.hosts | map_values({track, revision, ready, missing})), fixtures, compositions, existingInstallations, sops, desktop}'

# Check ciphertext before Nix evaluates/builds secret manifests; never decrypt.
# Canonical non-destructive validation; does not install, mount or deploy.
check: secret-check format-check lint evaluate
    nix flake check --no-update-lock-file -L

inventory:
    nix eval --no-update-lock-file --json .#fleet | jq .

revisions:
    jq '.nodes | with_entries(select(.value.locked)) | map_values(.locked | {rev, narHash, url})' flake.lock

ready host:
    bash scripts/ready.sh "$1"

build host:
    bash scripts/ready.sh "$1"
    nix build --no-update-lock-file ".#nixosConfigurations.$1.config.system.build.toplevel"

# Fresh-install capability only; existing installations must refuse this.
# Builds a script for review. NEVER executes it or touches disks.
disk-plan host:
    bash scripts/ready.sh "$1" disk-plan
    nix build --no-update-lock-file --out-link "result-disko-$1" ".#nixosConfigurations.$1.config.system.build.diskoScript"

deploy host: check
    bash scripts/ready.sh "$1" deploy
    deploy ".#$1" -- --no-update-lock-file

deploy-fleet: check
    nix eval --no-update-lock-file --json .#deploy.nodes --apply builtins.attrNames | jq -e 'length > 0' > /dev/null
    deploy . -- --no-update-lock-file
