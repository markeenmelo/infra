#!/usr/bin/env bash
set -euo pipefail

internal_output="eDP-1"
internal_mode="1920x1200@60.003"
internal_width=1920

usage() {
  printf 'usage: fleet-output-policy {sync|dry-run|watch}\n' >&2
  exit 2
}

lid_is_closed() {
  local state

  for state in /proc/acpi/button/lid/*/state; do
    [[ -r "$state" ]] || continue
    if grep -Eq 'state:[[:space:]]+closed' "$state"; then
      return 0
    fi
  done

  return 1
}

supports_hdr() {
  local connector decoded edid output=$1

  for connector in /sys/class/drm/card*-"$output"; do
    edid="$connector/edid"
    [[ -r "$edid" ]] || continue
    decoded=$(edid-decode "$edid" 2>/dev/null) || continue
    grep -F 'BT2020RGB' <<<"$decoded" >/dev/null || continue
    grep -F 'SMPTE ST2084' <<<"$decoded" >/dev/null || continue
    grep -F 'HDR Static Metadata Data Block:' <<<"$decoded" >/dev/null || continue
    return 0
  done

  return 1
}

external_rows() {
  jq -r --arg internal "$internal_output" '
    map(
      select(.name != $internal)
      | (
          if ((.availableModes // []) | length) > 0 then
            .availableModes[0]
          else
            ((.width | tostring) + "x" + (.height | tostring) + "@" + (.refreshRate | tostring))
          end
        ) as $rawMode
      | ($rawMode | sub("Hz$"; "")) as $mode
      | ($mode | capture("^(?<width>[0-9]+)x(?<height>[0-9]+)")) as $size
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
  ' "$1"
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
  local height mode name rule width

  while IFS=$'\t' read -r name mode width height; do
    [[ -n "$name" ]] || continue

    rule="$name,$mode,${external_width}x0,1,bitdepth,8,cm,srgb,vrr,0"
    if supports_hdr "$name"; then
      rule="$name,$mode,${external_width}x0,1,bitdepth,10,cm,hdredid,vrr,0"
    fi
    apply_rule "$dry_run" "$rule"

    ((external_count += 1))
    ((external_width += width))
    if ((height > external_height)); then
      external_height=$height
    fi
  done < <(external_rows "$monitors")

  if ((external_count > 0)) && lid_is_closed; then
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
  jq -e 'type == "array"' "$monitors_file" >/dev/null
  sync_outputs_unlocked "$dry_run" "$monitors_file"
)

watch_outputs() {
  local event socket

  : "${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}"
  : "${HYPRLAND_INSTANCE_SIGNATURE:?HYPRLAND_INSTANCE_SIGNATURE is required}"
  socket="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

  sync_outputs false

  while true; do
    if [[ ! -S "$socket" ]]; then
      sleep 1
      continue
    fi

    while IFS= read -r event; do
      case "$event" in
        monitoradded* | monitorremoved*)
          # Let Hyprland finish publishing the new output set before querying it.
          sleep 0.2
          if ! sync_outputs false; then
            printf 'fleet-output-policy: failed to process %s\n' "$event" >&2
          fi
          ;;
      esac
    done < <(socat -u "UNIX-CONNECT:$socket" - || true)

    sleep 1
  done
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
