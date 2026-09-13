#!/usr/bin/env bash
set -euo pipefail
[[ $# == 1 && $1 =~ ^/dev/disk/by-(id|path)/[a-zA-Z0-9._:+-]+$ && ! $1 =~ -part[0-9]+$ ]]
[[ $(id -u) == 0 ]]
grep -Eq '^VARIANT_ID="?installer"?$' /etc/os-release
case $(findmnt -n -o FSTYPE /) in overlay|tmpfs) ;; *) exit 1 ;; esac
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
device=$(readlink -f "$1")
[[ -b $device ]]
lsblk --json --bytes --output PATH,TYPE,SIZE,MODEL,SERIAL,MOUNTPOINTS "$device"
