#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit nullglob

internal_output="@internalOutput@"
internal_mode="@internalMode@"

usage() {
  printf 'usage: fleet-output-policy {sync|dry-run|watch}\n' >&2
  exit 2
}

read_lid_state() {
  local state contents

  for state in /proc/acpi/button/lid/*/state; do
    IFS= read -r contents <"$state"
    if [[ "$contents" =~ ^state:[[:space:]]+closed$ ]]; then
      printf 'closed\n'
      return
    fi
    if [[ ! "$contents" =~ ^state:[[:space:]]+open$ ]]; then
      printf 'fleet-output-policy: invalid lid state in %s\n' "$state" >&2
      return 1
    fi
  done

  printf 'open\n'
}

supports_hdr() {
  local connector decoded status output=$1

  for connector in /sys/class/drm/card*-"$output"; do
    IFS= read -r status <"$connector/status"
    [[ "$status" == connected ]] || continue
    decoded=$(edid-decode "$connector/edid")
    if [[ "$decoded" == *BT2020RGB* && "$decoded" == *'SMPTE ST2084'* &&
      "$decoded" == *'HDR Static Metadata Data Block:'* ]]; then
      printf 'true\n'
      return
    fi
  done

  printf 'false\n'
}

external_rows() {
  local connector name status active_only=${2:-false}
  local -a connected=()

  for connector in /sys/class/drm/card*-*/status; do
    IFS= read -r status <"$connector"
    [[ "$status" == connected ]] || continue
    name=${connector%/status}
    name=${name##*/}
    connected+=("${name#*-}")
  done

  jq -nr --arg internal "$internal_output" --argjson activeOnly "$active_only" --slurpfile monitors "$1" '
    $monitors
    | if length == 1 and (.[0] | type == "array") then .[0]
      else error("expected one monitor array") end
    | map(
      if (.name | type == "string" and length > 0) then .
      else error("invalid monitor name") end
      | select(.name as $name | $name != $internal and ($ARGS.positional | index($name)) != null)
      | if (.name | test("^[A-Za-z0-9_-]+$")) then .
        else error("invalid DRM output name") end
      | if (.disabled | type) != "boolean" or (.dpmsStatus | type) != "boolean"
          or (.width | type) != "number" or (.height | type) != "number"
        then error("invalid monitor state") else . end
      | if $activeOnly then
          select(.disabled == false and .dpmsStatus == true and .width > 0 and .height > 0)
        else . end
    )
    | sort_by(.name)
    | .[]
    | .name
  ' --args "${connected[@]}"
}

apply_rule() {
  local dry_run=$1 rule="hl.monitor({ $2 })" reply

  if [[ "$dry_run" == true ]]; then
    printf '%s\n' "$rule"
  else
    reply=$(hyprctl eval "$rule")
    if [[ "$reply" != ok ]]; then
      printf 'fleet-output-policy: monitor update rejected: %s\n' "$reply" >&2
      return 1
    fi
  fi
}

sync_outputs_unlocked() {
  local dry_run=$1 monitors=$2
  local external_count=0
  local bitdepth cm hdr lid name position rows

  rows=$(external_rows "$monitors")
  lid=$(read_lid_state)

  while IFS= read -r name; do
    [[ -n "$name" ]] || continue

    bitdepth=8
    cm=srgb
    hdr=$(supports_hdr "$name")
    if [[ "$hdr" == true ]]; then
      bitdepth=10
      cm=hdredid
    fi
    position=auto-center-up
    if [[ "$lid" == closed ]] && ((external_count == 0)); then
      position=0x0
    fi
    apply_rule "$dry_run" \
      "output = \"$name\", mode = \"preferred\", position = \"$position\", scale = 1, bitdepth = $bitdepth, cm = \"$cm\", vrr = 0, disabled = false"

    ((external_count += 1))
  done <<<"$rows"

  if ((external_count > 0)) && [[ "$lid" == closed ]]; then
    if [[ "$dry_run" == false ]]; then
      sleep 0.2
      hyprctl monitors -j >"$monitors"
      rows=$(external_rows "$monitors" true)
      if [[ -z "$rows" ]]; then
        printf 'fleet-output-policy: no active external; refusing to disable panel\n' >&2
        return 1
      fi
    fi
    apply_rule "$dry_run" "output = \"$internal_output\", disabled = true"
  else
    apply_rule "$dry_run" \
      "output = \"$internal_output\", mode = \"$internal_mode\", position = \"0x0\", scale = 1, bitdepth = 8, cm = \"srgb\", vrr = 0, disabled = false"
  fi
}

sync_outputs() (
  local dry_run=$1
  local lock="${XDG_RUNTIME_DIR:-/tmp}/fleet-output-policy.lock"
  local monitors_file

  monitors_file=$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/fleet-output-policy.XXXXXX")
  trap 'rm -f "${monitors_file:-}"' EXIT

  exec 9>"$lock"
  flock -x 9
  hyprctl monitors all -j >"$monitors_file"
  sync_outputs_unlocked "$dry_run" "$monitors_file"
)

watch_outputs() {
  local event socket

  : "${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}"
  : "${HYPRLAND_INSTANCE_SIGNATURE:?HYPRLAND_INSTANCE_SIGNATURE is required}"
  socket="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

  socat -u "UNIX-CONNECT:$socket" 'SYSTEM:echo subscribed; exec cat,nofork' | {
    if IFS= read -r event; then
      [[ "$event" == subscribed ]] || return 1
    else
      return 0
    fi
    sleep 0.5
    sync_outputs false

    while IFS= read -r event; do
      case "${event%%>>*}" in
        monitoradded | monitorremoved | configreloaded)
          sleep 0.2
          sync_outputs false
          ;;
      esac
    done
  }
}

case "${1:-}" in
  sync)
    sleep 0.1
    sync_outputs false
    ;;
  dry-run)
    sync_outputs true
    ;;
  watch)
    watch_outputs
    ;;
  *)
    usage
    ;;
esac
