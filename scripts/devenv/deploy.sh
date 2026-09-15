#!/usr/bin/env bash
set -euo pipefail

die() { printf '%s\n' "$*" >&2; exit 1; }

input=${DEVENV_TASK_INPUT:-'{}'}
[[ $# == 0 ]] || die 'Use fleet:deploy --input target=HOST|servers [--input boot=true].'
jq -e '
  type == "object" and
  (keys - ["target", "boot"] == []) and
  (.target | type == "string") and
  ((has("boot") | not) or (.boot | type == "boolean"))
' <<<"$input" >/dev/null || die 'Use fleet:deploy --input target=HOST|servers [--input boot=true].'
target=$(jq -r '.target' <<<"$input")
boot=$(jq -r '.boot // false' <<<"$input")
case "$target" in
  servers) hosts=(racknerd bastion) ;;
  racknerd|bastion) hosts=("$target") ;;
  *) die 'Deployment targets: racknerd, bastion, servers. ThinkPad is install-only.' ;;
esac

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
status=$(git status --porcelain --untracked-files=all)
[[ -z $status ]] || die 'Deployment requires a clean, reviewed, committed tree.'
flake="git+file://$(pwd -P)?rev=$(git rev-parse HEAD)"
nodes=$(nix eval --no-update-lock-file --json "$flake#deploy.nodes" \
  --apply 'nodes: builtins.mapAttrs (_: n: removeAttrs n ["profiles"]) nodes')
targets=()
for host in "${hosts[@]}"; do
  jq -e --arg host "$host" 'has($host)' <<<"$nodes" >/dev/null \
    || die "Not a deploy node: $host"
  targets+=("$flake#$host")
done

if [[ $boot == false ]]; then
  exec nix run --no-update-lock-file "$flake#deploy-rs" -- \
    --checksigs --targets "${targets[@]}" -- --no-update-lock-file
fi

for host in "${hosts[@]}"; do
  hostname=$(jq -er --arg host "$host" '.[$host].hostname' <<<"$nodes")
  user=$(jq -er --arg host "$host" '.[$host].sshUser' <<<"$nodes")
  options=$(jq -er --arg host "$host" '.[$host].sshOpts[]' <<<"$nodes")
  readarray -t ssh_options <<<"$options"
  nix run --no-update-lock-file "$flake#deploy-rs" -- \
    --checksigs --boot --targets "$flake#$host" -- --no-update-lock-file
  printf 'Requesting reboot of %s; completed boot must be verified separately.\n' "$host"
  ssh "${ssh_options[@]}" -l "$user" -- "$hostname" \
    'sudo -n /run/current-system/sw/bin/systemctl reboot' \
    || die "Reboot request failed or its outcome is unknown for $host; inspect console before continuing."
done
