#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit nullglob

internal_output="@internalOutput@"
internal_mode="@internalMode@"
internal_width=@internalWidth@

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

  # No lid switch means the internal panel must stay enabled.
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

  # Hyprland 0.56 has no virtual flag in monitor JSON. Only connected DRM
  # connectors may replace the panel, never FALLBACK or named headless outputs.
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
      | if $activeOnly then
          if (.disabled | type) != "boolean" or (.dpmsStatus | type) != "boolean"
            or (.width | type) != "number" or (.height | type) != "number"
          then error("invalid active monitor state")
          else select(.disabled == false and .dpmsStatus == true and .width > 0 and .height > 0) end
        else . end
      | (
          if (.availableModes | type) != "array" then error("invalid availableModes")
          elif (.availableModes | length) > 0 then .availableModes[0]
          else
            ((.width | tostring) + "x" + (.height | tostring) + "@" + (.refreshRate | tostring))
          end
        ) as $rawMode
      | ($rawMode | sub("Hz$"; "")) as $mode
      | ($mode | capture("^(?<width>[0-9]+)x(?<height>[0-9]+)@[0-9]+(\\.[0-9]+)?$")
          // error("invalid monitor mode")) as $size
      | if ($size.width | tonumber) > 0 and ($size.height | tonumber) > 0 then .
        else error("invalid monitor dimensions") end
      | {
          name: .name,
          mode: $mode,
          width: ($size.width | tonumber),
          height: ($size.height | tonumber)
        }
    )
    | sort_by(.name)
    | .[]
    | [.name, .mode, .width, .height]
    | @tsv
  ' --args "${connected[@]}"
}

apply_rule() {
  local dry_run=$1 rule="hl.monitor({ $2 })" reply

  if [[ "$dry_run" == true ]]; then
    printf '%s\n' "$rule"
  else
    # Lua IPC reports rejected operations on stdout even when hyprctl exits 0.
    # Only the exact success token is acceptance; transport errors propagate.
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
  local external_height=0
  local external_width=0
  local bitdepth cm hdr height lid mode name rows width

  # Decode the complete snapshot before any modeset; process substitution hides
  # producer failures. Keep these calls out of conditionals so errexit applies.
  rows=$(external_rows "$monitors")
  lid=$(read_lid_state)

  while IFS=$'\t' read -r name mode width height; do
    [[ -n "$name" ]] || continue

    bitdepth=8
    cm=srgb
    hdr=$(supports_hdr "$name")
    if [[ "$hdr" == true ]]; then
      bitdepth=10
      cm=hdredid
    fi
    apply_rule "$dry_run" \
      "output = \"$name\", mode = \"$mode\", position = \"${external_width}x0\", scale = 1, bitdepth = $bitdepth, cm = \"$cm\", vrr = 0, disabled = false"

    ((external_count += 1))
    ((external_width += width))
    if ((height > external_height)); then
      external_height=$height
    fi
  done <<<"$rows"

  if ((external_count > 0)) && [[ "$lid" == closed ]]; then
    if [[ "$dry_run" == false ]]; then
      # hl.monitor only queues a rule. Confirm a usable physical output in a
      # fresh active snapshot, not command acceptance or advertised modes.
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
    local internal_x=0
    local internal_y=0
    if ((external_count > 0)); then
      internal_x=$(((external_width - internal_width) / 2))
      internal_y=$external_height
    fi

    apply_rule "$dry_run" \
      "output = \"$internal_output\", mode = \"$internal_mode\", position = \"${internal_x}x${internal_y}\", scale = 1, bitdepth = 8, cm = \"srgb\", vrr = 0, disabled = false"
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

  # Subscribe before waiting so monitor events are buffered. The Hyprland start
  # callback can run before initial DRM/output publication; without this delay,
  # its later static monitor rules can remain active until another event occurs.
  # Socat opens the socket BEFORE exec (nofork). Its fixed local marker gates
  # all mutations; pipefail preserves connection/read failures without reconnect.
  socat -u "UNIX-CONNECT:$socket" 'SYSTEM:echo subscribed; exec cat,nofork' | {
    if IFS= read -r event; then
      [[ "$event" == subscribed ]] || return 1
    else
      # The producer failed before exec; leave its status to pipefail.
      return 0
    fi
    sleep 0.5
    sync_outputs false

    while IFS= read -r event; do
      case "${event%%>>*}" in
        monitoradded | monitorremoved | configreloaded)
          # Let Hyprland finish publishing the new output set before querying it.
          sleep 0.2
          sync_outputs false
          ;;
      esac
    done
  }
}

case "${1:-}" in
  sync)
    # The kernel switch state can settle just after the compositor bind fires.
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
