#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit nullglob

internal_output="eDP-1"
internal_mode="1920x1200@60.003"
internal_width=1920

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
  local connector name status
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

  jq -nr --arg internal "$internal_output" --slurpfile monitors "$1" '
    $monitors
    | if length == 1 and (.[0] | type == "array") then .[0]
      else error("expected one monitor array") end
    | map(
      if (.name | type == "string" and length > 0) then .
      else error("invalid monitor name") end
      | select(.name as $name | $name != $internal and ($ARGS.positional | index($name)) != null)
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
  local dry_run=$1 rule=$2

  if [[ "$dry_run" == true ]]; then
    printf 'monitor %s\n' "$rule"
  else
    hyprctl keyword monitor "$rule" >/dev/null
  fi
}

sync_outputs_unlocked() {
  local dry_run=$1 monitors=$2
  local external_count=0
  local external_height=0
  local external_width=0
  local hdr height lid mode name rows rule width

  # Decode the complete snapshot before any modeset; process substitution hides
  # producer failures. Keep these calls out of conditionals so errexit applies.
  rows=$(external_rows "$monitors")
  lid=$(read_lid_state)

  while IFS=$'\t' read -r name mode width height; do
    [[ -n "$name" ]] || continue

    rule="$name,$mode,${external_width}x0,1,bitdepth,8,cm,srgb,vrr,0"
    hdr=$(supports_hdr "$name")
    if [[ "$hdr" == true ]]; then
      rule="$name,$mode,${external_width}x0,1,bitdepth,10,cm,hdredid,vrr,0"
    fi
    apply_rule "$dry_run" "$rule"

    ((external_count += 1))
    ((external_width += width))
    if ((height > external_height)); then
      external_height=$height
    fi
  done <<<"$rows"

  if ((external_count > 0)) && [[ "$lid" == closed ]]; then
    apply_rule "$dry_run" "$internal_output,disable"
  else
    local internal_x=0
    local internal_y=0
    if ((external_count > 0)); then
      internal_x=$(((external_width - internal_width) / 2))
      internal_y=$external_height
    fi

    apply_rule "$dry_run" \
      "$internal_output,$internal_mode,${internal_x}x${internal_y},1,bitdepth,8,cm,srgb,vrr,0"
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
  # pipefail preserves socket failures; a failed sync terminates the watcher
  # instead of continuing with later rules/events after a partial update.
  socat -u "UNIX-CONNECT:$socket" - | {
    sleep 0.5
    sync_outputs false

    while IFS= read -r event; do
      case "${event%%>>*}" in
        monitoradded | monitoraddedv2 | monitorremoved | monitorremovedv2 | configreloaded)
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
