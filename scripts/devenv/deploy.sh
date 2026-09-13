#!/usr/bin/env bash
set -euo pipefail
if [[ $- == *x* ]]; then set +x; echo 'Refusing deployment with shell tracing.' >&2; exit 1; fi
cd "${DEVENV_ROOT:?Enter the locked devenv shell}"
if [[ $# == 3 ]]; then
  input=$(jq -cn --arg target "$1" --arg mode "$2" --arg confirm "$3" '{target:$target,mode:$mode,confirm:$confirm}')
elif [[ $# == 0 ]]; then
  input=${DEVENV_TASK_INPUT:-\{\}}
else
  echo 'Usage: deploy TARGET {boot|switch} "DEPLOY TARGET MODE"; or deploy:run task inputs.' >&2
  exit 1
fi
jq -e 'type == "object" and keys == ["confirm","mode","target"]
  and (.target | type == "string" and test("^[a-z][a-z0-9-]*$"))
  and (.mode == "boot" or .mode == "switch")
  and .confirm == ("DEPLOY " + .target + " " + .mode)' <<<"$input" >/dev/null 2>&1 || {
  echo 'Refusing: supply exact target, boot|switch mode and "DEPLOY TARGET MODE" confirmation.' >&2
  exit 1
}
if [[ -v LOCAL_KEY || -v SSH_PRIVATE_KEY || -v SSHPASS ]]; then
  echo 'Refusing inherited signing/password/key contents; use reviewed private SSH configuration.' >&2
  exit 1
fi
[[ -z $(git status --porcelain) ]] || { echo 'Commit the reviewed candidate before deployment.' >&2; exit 1; }
revision=$(git rev-parse HEAD)
selector=$(jq -r '.target' <<<"$input")
mode=$(jq -r '.mode' <<<"$input")
bash scripts/devenv/preflight.sh
plan=$(nix eval --no-update-lock-file --json .#deploymentPlan)
case "$selector" in
  servers|workstations)
    group=$(nix eval --no-update-lock-file --json ".#deploymentGroups.$selector")
    jq -e 'type == "array" and length > 0 and all(.[]; type == "string" and test("^[a-z][a-z0-9-]*$"))' <<<"$group" >/dev/null
    mapfile -t hosts < <(jq -r '.[]' <<<"$group")
    ;;
  *) hosts=("$selector") ;;
esac
for host in "${hosts[@]}"; do
  jq -e --arg host "$host" --arg mode "$mode" '.[$host] | .ready and .enable
    and .hostname != null and .sshUser == "deploy" and .profileUser == "root"
    and .transport == "trusted-user" and .remoteBuild and .autoRollback and .magicRollback
    and (.interactiveSudo | not) and .sudo == "sudo -n -u"
    and ((.bootOnly | not) or $mode == "boot")' <<<"$plan" >/dev/null || {
    echo "Refusing: $host is ineligible or requires boot-only deployment." >&2
    exit 1
  }
  bash scripts/fleet/ready.sh "$host" deploy
  nix build --no-update-lock-file --no-link ".#nixosConfigurations.$host.config.system.build.toplevel"
done
for host in "${hosts[@]}"; do
  node=$(nix eval --no-update-lock-file --json ".#deploy.nodes.$host")
  jq -e '.sshUser == "deploy" and (.hostname | type == "string" and length > 0)
    and (.sshOpts | type == "array" and length > 0 and all(.[]; type == "string" and (test("[[:space:]]") | not))
      and index("StrictHostKeyChecking=yes") != null and index("BatchMode=yes") != null)' <<<"$node" >/dev/null
  ssh_rows=$(jq -r '.sshOpts[]' <<<"$node")
  mapfile -t ssh_opts <<<"$ssh_rows"
  address=$(jq -r '.sshUser + "@" + .hostname' <<<"$node")
  ssh "${ssh_opts[@]}" "$address" 'test "$(id -un)" = deploy && sudo -n -l >/dev/null && test -d /run/deploy-rs && test -d /nix/store'
  trusted=$(ssh "${ssh_opts[@]}" "$address" 'nix config show trusted-users')
  [[ " $trusted " == *' deploy '* ]] || { echo "$host: installed deploy Nix trust is missing." >&2; exit 1; }
done
[[ -z $(git status --porcelain) && $(git rev-parse HEAD) == "$revision" ]] || { echo 'Candidate changed during preflight; refusing.' >&2; exit 1; }
args=(--checksigs)
[[ $mode != boot ]] || args+=(--boot)
args+=(--targets)
for host in "${hosts[@]}"; do args+=(".#$host"); done
args+=(-- --no-update-lock-file)
printf 'Deploying in activation order: %s (%s); automatic/magic rollback retained.\n' "${hosts[*]}" "$mode"
exec nix run --no-update-lock-file .#deploy-rs -- "${args[@]}"
