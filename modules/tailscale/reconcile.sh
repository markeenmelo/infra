#!/usr/bin/env bash
# Only the enabled, reviewed NixOS unit executes this against a real daemon.
# Checks execute it with a mocked CLI; no private state file is ever parsed.
set -euo pipefail
set +x

fail() { printf '%s\n' "$1" >&2; exit 1; }
[[ $# == 4 ]] || fail 'Expected enrollment mode, hostname, tag and runtime key path.'
mode=$1 host=$2 tag=$3 key_path=$4
[[ "$mode" == auth-key || "$mode" == preserve ]] || fail 'Enrollment mode is not configured.'
[[ "$host" =~ ^[a-z][a-z0-9-]*$ && "$tag" == "tag:fleet-$host" ]] || fail 'Hostname/tag mismatch.'
if [[ "$mode" == auth-key ]]; then
  [[ "$key_path" =~ ^/run/secrets/[a-zA-Z0-9_-]+$ ]] || fail 'Expected a runtime SOPS secret path.'
else
  [[ -z "$key_path" ]] || fail 'Preservation must not have an enrollment key.'
fi

status() {
  tailscale status --json --peers=false 2>/dev/null || fail 'Cannot query Tailscale self status; inspect privately.'
}
state=''
for ((attempt = 0; attempt < 30; attempt++)); do
  state=$(status | jq -er '.BackendState | select(type == "string")')
  [[ "$state" == Starting || "$state" == NoState ]] || break
  sleep 1
done

# Both up and set support these settings. Never reset unknown preferences or
# force reauthentication: an incompatible old configuration must fail review.
flags=(
  --accept-dns=true --accept-routes=false --ssh=false --shields-up=false
  --advertise-routes= --advertise-exit-node=false --advertise-connector=false
  --exit-node= --exit-node-allow-lan-access=false --operator=
  --netfilter-mode=on "--hostname=$host"
)
case "$state" in
  NeedsLogin)
    [[ "$mode" == auth-key ]] || fail 'Preserved node needs login; explicit enrollment review is required.'
    # Keep keys out of argv and suppress possible login URLs/error payloads.
    tailscale up "--auth-key=file:$key_path" "--advertise-tags=$tag" --timeout=60s "${flags[@]}" >/dev/null 2>&1 \
      || fail 'Tailscale enrollment failed; check credentials/preferences privately. No forced reset was attempted.'
    ;;
  Running|Stopped) ;;
  NeedsMachineAuth) fail 'Tailscale requires administrator device approval; no enrollment key was resubmitted.' ;;
  *) fail 'Tailscale is not ready for reconciliation; no enrollment attempted.' ;;
esac

tailscale set "${flags[@]}" --auto-update=false --webclient=false >/dev/null 2>&1 \
  || fail 'Tailscale preference reconciliation failed; inspect privately.'
if [[ "$state" == Stopped ]]; then
  # Reconnect the existing identity without supplying another enrollment key.
  # Even --timeout counts as an explicit up flag and triggers upstream's
  # accidental-preference-reset check. Bound a genuinely bare up externally.
  timeout 60s tailscale up >/dev/null 2>&1 || fail 'Could not reconnect the preserved Tailscale identity.'
fi
status | jq -e --arg tag "$tag" '
  .BackendState == "Running" and (.Self.ID | type == "string" and length > 0)
  and .Self.Tags == [$tag]
' >/dev/null || fail 'Expected a running node with exactly its reviewed fleet tag; verify the tailnet privately.'
printf 'Tailscale client reconciled; runtime connectivity still requires acceptance.\n'
