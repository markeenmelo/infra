#!/usr/bin/env bash
set -euo pipefail

check_kernel_holders() {
  local sysfs=$1 nodes=$2 node
  local -a holders
  [[ -n $nodes ]] || return 1
  while IFS= read -r node; do
    [[ $node =~ ^[a-zA-Z0-9._!-]+$ && -d $sysfs/$node/holders && -r $sysfs/$node/holders && -x $sysfs/$node/holders ]] || return 1
    shopt -s nullglob dotglob
    holders=("$sysfs/$node/holders/"*)
    if ((${#holders[@]})); then
      echo 'Refusing an OS disk or partition with active kernel holders.' >&2
      return 1
    fi
  done <<<"$nodes"
}

inventory() {
  [[ $# == 1 && $1 =~ ^/dev/disk/by-(id|path)/[a-zA-Z0-9._:+-]+$ && ! $1 =~ -part[0-9]+$ ]]
  [[ $(id -u) == 0 ]]
  grep -Eq '^VARIANT_ID="?installer"?$' /etc/os-release
  case $(findmnt -n -o FSTYPE /) in overlay|tmpfs) ;; *) exit 1 ;; esac
  local mounts pools swaps device nodes
  mounts=$(findmnt -rn -o TARGET)
  if grep -Eq '^/mnt(/|$)' <<<"$mounts"; then
    echo 'Refusing an installer with existing /mnt mounts.' >&2
    exit 1
  fi
  if command -v zpool >/dev/null; then
    pools=$(zpool list -H -o name)
    if [[ -n $pools ]]; then
      echo 'Refusing installation while any ZFS pool is imported.' >&2
      exit 1
    fi
  fi
  swaps=$(swapon --show=NAME --noheadings --raw)
  if [[ -n $swaps ]]; then
    echo 'Refusing installation while any swap is active.' >&2
    exit 1
  fi
  device=$(readlink -f "$1")
  [[ -b $device ]]
  nodes=$(lsblk --noheadings --raw --output KNAME "$device")
  check_kernel_holders /sys/class/block "$nodes"
  lsblk --json --bytes --output PATH,TYPE,SIZE,MODEL,SERIAL,MOUNTPOINTS "$device"
}

if [[ ${BASH_SOURCE[0]:-$0} == "$0" ]]; then
  inventory "$@"
fi
