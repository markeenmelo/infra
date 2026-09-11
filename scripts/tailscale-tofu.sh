#!/usr/bin/env bash
# Operator-only entry point. Never called by shell entry, checks or rebuilding.
set -euo pipefail
set +x
umask 077
fail() { printf '%s\n' "$1" >&2; exit 1; }
[[ $# == 1 ]] || fail 'Usage: tailscale-tofu.sh init|plan|verify|apply|import-policy|import-dns'
case "$1" in init|plan|verify|apply|import-policy|import-dns) ;; *) fail 'Unsupported operation.' ;; esac
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
expected_tailnet=$(jq -er '.id | select(type == "string") | select(length > 0 and . != "-" and (test("\\s") | not))' "$root/tofu/tailscale/tailnet.json") \
  || fail 'The checked-in public tailnet identity is missing or invalid.'
[[ ${TAILSCALE_TAILNET-$expected_tailnet} == "$expected_tailnet" ]] \
  || fail 'TAILSCALE_TAILNET must match tailnet.json; it cannot select another tailnet.'
export TAILSCALE_TAILNET="$expected_tailnet"
[[ -z ${TAILSCALE_BASE_URL:-} ]] || fail 'TAILSCALE_BASE_URL overrides are forbidden; use the pinned provider endpoint.'
[[ ${TAILSCALE_STATE_DIR:-} == /* ]] || fail 'Set TAILSCALE_STATE_DIR to an absolute private path outside Git.'
state=$(realpath -m -- "$TAILSCALE_STATE_DIR")
[[ "$state" != "$root" && "$state" != "$root/"* && "$state" != /nix/store && "$state" != /nix/store/* ]] \
  || fail 'State and plans must remain outside the checkout and Nix store.'
[[ -n ${TF_VAR_state_passphrase:-} ]] || fail 'Supply TF_VAR_state_passphrase privately; no passphrase is configured.'
[[ ${#TF_VAR_state_passphrase} -ge 32 ]] || fail 'Supply TF_VAR_state_passphrase privately (at least 32 characters); do not pass it in arguments.'
[[ -z ${TF_ENCRYPTION:-} && -z ${TF_LOG:-} && -z ${TF_LOG_PATH:-} && -z ${TF_LOG_PROVIDER:-} && -z ${TF_LOG_CORE:-} ]] \
  || fail 'Encryption overrides and debug logging are forbidden for this credential-bearing workflow.'
[[ ${TF_WORKSPACE:-default} == default ]] || fail 'Use one directory per tailnet, not workspaces.'
for variable in ${!TF_CLI_ARGS@}; do
  [[ -z ${!variable} ]] || fail 'Unset TF_CLI_ARGS overrides; locking and explicit application must remain enabled.'
done
if [[ "$1" == init ]]; then
  mkdir -p -- "$state"
fi
[[ -d "$state" && $(stat -c '%a:%u' "$state") == "700:$(id -u)" ]] \
  || fail 'State directory must already be owned by you with mode 0700; no permissions are changed automatically.'
if [[ -f "$state/tailnet-id" ]]; then
  IFS= read -r recorded < "$state/tailnet-id"
  [[ "$recorded" == "$TAILSCALE_TAILNET" ]] || fail 'This state directory belongs to another tailnet; do not repurpose it.'
else
  [[ "$1" == init && -z $(find "$state" -mindepth 1 -maxdepth 1 -print -quit) ]] \
    || fail 'An unbound/nonempty state directory requires manual recovery review.'
  printf '%s\n' "$TAILSCALE_TAILNET" > "$state/tailnet-id"
fi
# Auto-loaded files take precedence over environment variables. Do not let an
# ignored local file silently redirect the confirmed tailnet/backend or crypto.
[[ -z $(find "$root/tofu/tailscale" -maxdepth 1 \( -name '*.tfvars' -o -name '*.tfvars.json' -o -name '*override.tf' -o -name '*override.tf.json' \) -print -quit) ]] \
  || fail 'Remove/review auto-loaded variable or override files; this workflow uses runtime environment inputs only.'
export TF_VAR_tailnet="$TAILSCALE_TAILNET" TF_VAR_state_directory="$state" TF_DATA_DIR="$state/provider-data"
export TF_IN_AUTOMATION=1
cd -- "$root/tofu/tailscale"
case "$1" in
  init) tofu init -input=false -lockfile=readonly ;;
  import-policy) tofu import -input=false -lock-timeout=60s tailscale_acl.policy acl ;;
  import-dns) tofu import -input=false -lock-timeout=60s tailscale_dns_preferences.tailnet dns_preferences ;;
  verify)
    # Read live resources without saving or replacing the retained apply plan.
    # Preserve native exit codes: 0 = no changes, 2 = drift, 1 = error.
    tofu plan -input=false -lock-timeout=60s -detailed-exitcode
    ;;
  plan)
    # Never leave an older plan available when a new plan attempt fails.
    [[ ! -e "$state/change.tfplan" ]] || fail 'A saved plan already exists. Review/archive it outside Git before creating another.'
    tofu plan -input=false -lock-timeout=60s -out="$state/change.tfplan"
    ;;
  apply)
    [[ -f "$state/change.tfplan" ]] || fail 'Create and review a saved plan first.'
    printf 'This changes the LIVE tailnet. Confirm recovery access and the reviewed plan.\nType the exact tailnet ID to apply: ' >&2
    IFS= read -r confirmation
    [[ "$confirmation" == "$TAILSCALE_TAILNET" ]] || fail 'Application cancelled.'
    tofu apply -input=false -lock-timeout=60s "$state/change.tfplan"
    printf 'Applied plan retained at %s/change.tfplan; archive it securely before the next plan.\n' "$state"
    ;;
esac
