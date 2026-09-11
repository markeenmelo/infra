#!/usr/bin/env bash
# Non-destructive preflight; never contacts the target.
set -euo pipefail
host=${1:?Usage: ready.sh HOST [deploy|disk-plan]}
[[ $host =~ ^[a-z][a-z0-9-]*$ ]] || { echo 'Invalid host name' >&2; exit 1; }
report=$(nix eval --no-update-lock-file --json ".#fleet.$host")
jq '{track, revision, ready, missing, failedAssertions}' <<< "$report"
if [[ ${2:-} == disk-plan ]]; then
  jq -e '.storageMode == "provision"' <<< "$report" > /dev/null || {
    echo 'Refusing: existing installations have no provisioning plan. See docs/hosts.md.' >&2
    exit 1
  }
fi
jq -e '.ready and (.missing | length == 0) and (.failedAssertions | length == 0) and (.nixpkgsPath == .intendedNixpkgsPath)' <<< "$report" > /dev/null || {
  echo 'Refusing: host is not commissioned. See docs/hosts.md for existing installs, docs/bootstrap.md for fresh installs.' >&2
  exit 1
}
# Force the independent policy oracle as well as actual NixOS toplevel evaluation.
nix eval --no-update-lock-file --json .#validation.hosts > /dev/null
nix eval --no-update-lock-file --raw ".#nixosConfigurations.$host.config.system.build.toplevel.drvPath"
printf '\n'
if [[ ${2:-} == deploy ]]; then
  nix eval --no-update-lock-file --json ".#deploymentPlan.$host" | jq -e '.enable and (.hostname != null) and (.sshUser != null)' > /dev/null
fi
