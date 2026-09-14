#!/usr/bin/env bash
set -euo pipefail

die() { printf '%s\n' "$*" >&2; exit 1; }

input=${DEVENV_TASK_INPUT:-'{}'}
[[ $# == 0 ]] || die 'Use fleet:install --input host=HOST.'
host=$(jq -er '
  select(type == "object" and keys == ["host"]) |
  .host | strings | select(test("^[a-z][a-z0-9-]*$"))
' <<<"$input") || die 'Use fleet:install --input host=HOST (one fleet hostname, no group).'

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
root=$(pwd -P)
status=$(git status --porcelain --untracked-files=all)
[[ -z $status ]] || die 'Installation requires a clean, reviewed, committed tree.'
flake="git+file://$root?rev=$(git rev-parse HEAD)"
hosts=$(nix eval --no-update-lock-file --json "$flake#fleet" --apply builtins.attrNames)
jq -e --arg host "$host" 'index($host) != null' <<<"$hosts" >/dev/null \
  || die "Not a fleet host: $host"

private=$(realpath -e -- "${XDG_DATA_HOME:-$HOME/.local/share}/infra/install/$host")
[[ -d $private && $private =~ ^/[a-zA-Z0-9/._+-]+$ ]] \
  || die 'Installer setup must be an existing directory with a path containing only letters, digits, /._+-.'
case "$private" in
  "$root"|"$root"/*|/nix/store|/nix/store/*) die 'Installer setup must be outside the checkout and Nix store.' ;;
esac
[[ $(stat -c %a "$private") == 700 ]] || die 'Installer setup directory must have mode 0700.'
unsafe=$(find "$private" \( ! -uid "$EUID" -o -perm /022 -o \( ! -type f -a ! -type d \) \) -print -quit)
[[ -z $unsafe ]] || die 'Installer setup must contain only operator-owned regular files and directories, without group/other write access or symlinks.'
unsafe=$(find "$private" -type f ! -path "$private/extra-files/persist/etc/machine-id" -perm /077 -print -quit)
[[ -z $unsafe ]] || die 'Installer files other than payload machine-id must be owner-only.'
for file in identity known_hosts disko.sha256 \
  extra-files/persist/etc/machine-id \
  extra-files/persist/etc/ssh/ssh_host_ed25519_key \
  extra-files/persist/etc/ssh/ssh_host_ed25519_key.pub; do
  [[ -f $private/$file && -s $private/$file && -r $private/$file ]] \
    || die "Missing readable, nonempty installer file: $file"
done
for dir in extra-files extra-files/persist extra-files/persist/etc extra-files/persist/etc/ssh \
  extra-files/persist/var extra-files/persist/var/lib; do
  if [[ -e $private/$dir ]]; then
    [[ -d $private/$dir && $(stat -c %a "$private/$dir") == 755 ]] \
      || die "Payload system directory must have mode 0755: $dir"
  fi
done
[[ $(stat -c %a "$private/extra-files/persist/etc/machine-id") == 444 ]] \
  || die 'Payload machine-id must have mode 0444 for unprivileged system services.'
has_secrets=$(nix eval --no-update-lock-file --json \
  "$flake#nixosConfigurations.$host.config.sops.secrets" --apply 'secrets: secrets != {}')
if [[ $has_secrets == true ]]; then
  [[ -s $private/extra-files/persist/var/lib/sops-nix/key.txt ]] \
    || die 'This host selects secrets; stage its reviewed persistent age identity first.'
fi
expected=$(<"$private/disko.sha256")
[[ $expected =~ ^[0-9a-f]{64}$ ]] || die 'disko.sha256 must contain only the reviewed script SHA-256 digest.'

alias="$host-installer"
hostname=$(ssh -G -o CanonicalizeHostname=no "root@$alias" | awk '$1 == "hostname" { print $2 }')
[[ -n $hostname && $hostname != "$alias" ]] || die "Configure the verified HostName for SSH alias $alias first."

disko=$(nix build --no-update-lock-file --no-link --print-out-paths \
  "$flake#nixosConfigurations.$host.config.system.build.diskoScript")
system=$(nix build --no-update-lock-file --no-link --print-out-paths \
  "$flake#nixosConfigurations.$host.config.system.build.toplevel")
actual=$(sha256sum "$disko")
[[ ${actual%% *} == "$expected" ]] || die 'Disko script differs from the reviewed digest; review it again before installation.'

printf 'Destructive install: %s via root@%s (%s). No kexec or reboot.\n' "$host" "$alias" "$hostname"
exec nixos-anywhere \
  --store-paths "$disko" "$system" \
  --target-host "root@$alias" \
  --phases disko,install --build-on local \
  -i "$private/identity" --extra-files "$private/extra-files" \
  --ssh-option "UserKnownHostsFile=$private/known_hosts" \
  --ssh-option GlobalKnownHostsFile=/dev/null \
  --ssh-option KnownHostsCommand=none \
  --ssh-option VerifyHostKeyDNS=no \
  --ssh-option StrictHostKeyChecking=yes \
  --ssh-option UpdateHostKeys=no \
  --ssh-option CanonicalizeHostname=no \
  --ssh-option ControlMaster=no \
  --ssh-option ControlPath=none \
  --ssh-option BatchMode=yes \
  --ssh-option PreferredAuthentications=publickey \
  --ssh-option PasswordAuthentication=no \
  --ssh-option KbdInteractiveAuthentication=no \
  --ssh-option IdentityAgent=none \
  --ssh-option IdentitiesOnly=yes \
  --ssh-option ForwardAgent=no \
  --ssh-option ClearAllForwardings=yes \
  --ssh-option ConnectTimeout=15 \
  --ssh-option ServerAliveInterval=10 \
  --ssh-option ServerAliveCountMax=3
