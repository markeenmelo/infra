#!/usr/bin/env bash
# Preserve the installed Bastion import policy. Only an authorized boot/service
# operation runs this on disks; tests supply synthetic commands and identities.
set -euo pipefail

pool="$BASTION_TANK_POOL"
pool_guid="$BASTION_TANK_POOL_GUID"
top_guid="$BASTION_TANK_TOP_GUID"
leaf_guids="$BASTION_TANK_LEAF_GUIDS"
member_aliases="$BASTION_TANK_MEMBER_ALIASES"
datasets="$BASTION_TANK_DATASETS"
dev_nodes="$BASTION_TANK_DEV_NODES"
attempts="$BASTION_TANK_IMPORT_ATTEMPTS"

if [[ -z "$pool" || -z "$pool_guid" || -z "$top_guid" || -z "$leaf_guids" || -z "$member_aliases" || -z "$datasets" || -z "$dev_nodes" ]]; then
  echo 'Refusing Bastion tank import: incomplete expected identity' >&2
  exit 1
fi
if [[ ! "$attempts" =~ ^[1-9][0-9]*$ ]]; then
  echo 'Refusing Bastion tank import: invalid attempt count' >&2
  exit 1
fi

read -r -a expected_leaf_guids <<< "$leaf_guids"
read -r -a expected_member_aliases <<< "$member_aliases"
if (( ${#expected_leaf_guids[@]} == 0 || ${#expected_member_aliases[@]} != ${#expected_leaf_guids[@]} )); then
  echo 'Refusing Bastion tank import: member alias and leaf GUID counts differ' >&2
  exit 1
fi
expected_member_identity_json="$(
  jq --null-input --compact-output --arg guids "$leaf_guids" --arg aliases "$member_aliases" '
    ($guids | split(" ")) as $guids
    | ($aliases | split(" ")) as $aliases
    | [range(0; ($guids | length)) as $index | {
        guid: $guids[$index], path: $aliases[$index]
      }]
    | sort_by(.guid)
  '
)"
declare -a import_search_args=()

verify_member_aliases() {
  local member_alias resolved_member
  local -A seen_members=()
  import_search_args=()
  for member_alias in "${expected_member_aliases[@]}"; do
    if [[ "$member_alias" != "$dev_nodes/"* ]]; then
      echo "Refusing Bastion tank import: member alias is outside $dev_nodes: $member_alias" >&2
      return 1
    fi
    if [[ ! -L "$member_alias" ]] || ! test -b "$member_alias"; then
      echo "Refusing Bastion tank import: expected member alias is not a block-device symlink: $member_alias" >&2
      return 1
    fi
    resolved_member="$(readlink -e -- "$member_alias")"
    if ! test -b "$resolved_member"; then
      echo 'Refusing Bastion tank import: member alias does not resolve to a block device' >&2
      return 1
    fi
    if [[ -n "${seen_members[$resolved_member]:-}" ]]; then
      echo 'Refusing Bastion tank import: member aliases resolve to the same block device' >&2
      return 1
    fi
    seen_members[$resolved_member]=1
    import_search_args+=( -d "$member_alias" )
  done
}

pool_ready() {
  local scan
  scan="$(zpool import "${import_search_args[@]}" 2>/dev/null || true)"
  awk -v expected_name="$pool" -v expected_guid="$pool_guid" '
    $1 == "pool:" { selected = ($2 == expected_name); next }
    selected && $1 == "id:" { id_ok = ($2 == expected_guid); next }
    selected && $1 == "state:" { state_ok = ($2 == "ONLINE"); next }
    END { exit !(id_ok && state_ok) }
  ' <<< "$scan"
}

verify_pool() {
  local expected_readonly="$1"
  local actual_guid actual_readonly compatibility dataset mountpoint encryption status_json expected_leaf_json
  local -a expected_datasets
  actual_guid="$(zpool get -H -o value guid "$pool")"
  if [[ "$actual_guid" != "$pool_guid" ]]; then
    echo 'Refusing Bastion tank mounts: pool GUID differs' >&2
    return 1
  fi
  actual_readonly="$(zpool get -H -o value readonly "$pool")"
  if [[ "$actual_readonly" != "$expected_readonly" ]]; then
    echo 'Refusing Bastion tank mounts: readonly policy differs' >&2
    return 1
  fi
  compatibility="$(zpool get -H -o value compatibility "$pool")"
  if [[ "$compatibility" != openzfs-2.4 ]]; then
    echo 'Refusing Bastion tank mounts: compatibility differs' >&2
    return 1
  fi
  read -r -a expected_datasets <<< "$datasets"
  for dataset in "${expected_datasets[@]}"; do
    if ! zfs list -H -o name "$dataset" >/dev/null 2>&1; then
      echo "Refusing Bastion tank mounts: missing dataset $dataset" >&2
      return 1
    fi
    mountpoint="$(zfs get -H -o value mountpoint "$dataset")"
    encryption="$(zfs get -H -o value encryption "$dataset")"
    if [[ "$mountpoint" != legacy || "$encryption" != off ]]; then
      echo "Refusing Bastion tank mounts: $dataset mountpoint/encryption differs" >&2
      return 1
    fi
  done
  status_json="$(zpool status -j --json-pool-key-guid "$pool")"
  expected_leaf_json="$(jq --null-input --compact-output --arg guids "$leaf_guids" '$guids | split(" ") | sort')"
  if ! jq --exit-status --arg poolGuid "$pool_guid" '
    .pools[$poolGuid] as $p
    | (
        ((($p | has("scan_stats")) == false)
          or (($p.scan_stats.errors == "0")
            and (($p.scan_stats.function != "RESILVER") or ($p.scan_stats.state == "FINISHED"))))
        and ([$p.vdevs | .. | objects | select(has("resilver_deferred"))] | length == 0)
      )
  ' <<< "$status_json" >/dev/null; then
    echo 'Refusing Bastion tank mounts: active/deferred resilver or scan errors recorded' >&2
    return 1
  fi
  if ! jq --exit-status --arg pool "$pool" --arg poolGuid "$pool_guid" --arg topGuid "$top_guid" \
    --argjson leafGuids "$expected_leaf_json" --argjson memberIdentities "$expected_member_identity_json" '
      .pools[$poolGuid] as $p
      | ($p.vdevs | to_entries | map(.value)) as $roots
      | ($roots[0].vdevs | to_entries | map(.value)) as $tops
      | ($tops[0].vdevs | to_entries | map(.value)) as $leaves
      | (
          ($p.name == $pool) and ($p.state == "ONLINE") and ($p.pool_guid == $poolGuid)
          and ($p.error_count == "0")
          and (($p | has("dedup")) == false) and (($p | has("special")) == false)
          and (($p | has("logs")) == false) and (($p | has("l2cache")) == false)
          and (($p | has("spares")) == false) and (($p | has("removal_stats")) == false)
          and (($p | has("raidz_expand_stats")) == false)
          and (($roots | length) == 1)
          and ($roots[0].vdev_type == "root") and ($roots[0].guid == $poolGuid)
          and ($roots[0].state == "ONLINE") and ($roots[0].read_errors == "0")
          and ($roots[0].write_errors == "0") and ($roots[0].checksum_errors == "0")
          and (($tops | length) == 1)
          and ($tops[0].vdev_type == "mirror") and ($tops[0].guid == $topGuid)
          and ($tops[0].state == "ONLINE") and ($tops[0].read_errors == "0")
          and ($tops[0].write_errors == "0") and ($tops[0].checksum_errors == "0")
          and (($leaves | length) == 2)
          and (([$leaves[].guid] | sort) == $leafGuids)
          and (([$leaves[] | {guid, path}] | sort_by(.guid)) == $memberIdentities)
          and (all($leaves[];
            (.vdev_type == "disk") and (.state == "ONLINE")
            and (.read_errors == "0") and (.write_errors == "0") and (.checksum_errors == "0")))
        )
    ' <<< "$status_json" >/dev/null; then
    echo 'Refusing Bastion tank mounts: pool topology or health differs from the reviewed mirror' >&2
    return 1
  fi
}

if zpool list -H -o name "$pool" >/dev/null 2>&1; then
  verify_member_aliases
  verify_pool off
  exit
fi

for ((attempt = 1; attempt <= attempts; attempt++)); do
  if verify_member_aliases && pool_ready; then
    # Inspect exact identity/topology read-only before any writable import.
    if ! zpool import "${import_search_args[@]}" -N -o readonly=on "$pool_guid"; then
      echo 'Refusing Bastion tank import: read-only preflight import failed' >&2
      exit 1
    fi
    if ! verify_pool on; then
      zpool export "$pool"
      exit 1
    fi
    zpool export "$pool"
    verify_member_aliases
    if zpool import "${import_search_args[@]}" -N "$pool_guid"; then
      if verify_pool off; then
        exit
      fi
      zpool export "$pool"
      exit 1
    fi
  fi
  if ((attempt < attempts)); then sleep 1; fi
done
echo "Refusing Bastion tank import: exact pool $pool_guid was not fully ONLINE after $attempts attempts" >&2
exit 1
