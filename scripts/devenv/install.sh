#!/usr/bin/env bash
set -euo pipefail

die() { printf '%s\n' "$*" >&2; exit 1; }

input=${DEVENV_TASK_INPUT:-'{}'}
usage='Use fleet:install --input host=HOST [--input prepare=true [--input knownHostsFile=/PATH] [--input reviewedDiskoSha256=DIGEST]].'
[[ $# == 0 ]] || die "$usage"
jq -e '
  type == "object" and
  ((keys - ["host", "prepare", "knownHostsFile", "reviewedDiskoSha256"]) | length == 0) and
  (.host | type == "string" and test("^[a-z][a-z0-9-]*$")) and
  ((has("prepare") | not) or (.prepare | type == "boolean")) and
  ((has("knownHostsFile") | not) or (.knownHostsFile | type == "string" and startswith("/"))) and
  ((has("reviewedDiskoSha256") | not) or (.reviewedDiskoSha256 | type == "string" and test("^[0-9a-f]{64}$"))) and
  (((has("knownHostsFile") or has("reviewedDiskoSha256")) | not) or .prepare == true)
' <<<"$input" >/dev/null 2>&1 || die "$usage"
host=$(jq -r '.host' <<<"$input")
prepare=$(jq -r '.prepare // false' <<<"$input")

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
root=$(pwd -P)
if [[ $prepare == true ]]; then
  flake="git+file://$root"
else
  status=$(git status --porcelain --untracked-files=all)
  [[ -z $status ]] || die 'Installation requires a clean, reviewed, committed tree.'
  flake="git+file://$root?rev=$(git rev-parse HEAD)"
fi
hosts=$(nix eval --no-update-lock-file --json "$flake#fleet" --apply builtins.attrNames)
jq -e --arg host "$host" 'index($host) != null' <<<"$hosts" >/dev/null \
  || die "Not a fleet host: $host"

setup="${XDG_DATA_HOME:-$HOME/.local/share}/infra/install/$host"
if [[ $prepare == true ]]; then
  [[ $setup == /* ]] || die 'Installer setup requires an absolute data-home path.'
  private=$(realpath -m -- "$setup")
  [[ $private == "$(realpath -ms -- "$setup")" ]] || die 'Preparation refuses symlinks in the setup path.'
else
  private=$(realpath -e -- "$setup")
fi
[[ $private =~ ^/[a-zA-Z0-9/._+-]+$ ]] \
  || die 'Installer setup path may contain only letters, digits, /._+-.'
case "$private" in
  "$root"|"$root"/*|/nix/store|/nix/store/*) die 'Installer setup must be outside the checkout and Nix store.' ;;
esac
if [[ $prepare == true && ! -e $private ]]; then
  (umask 077; mkdir -p -- "$private")
fi
[[ -d $private && $(stat -c %a "$private") == 700 ]] || die 'Installer setup directory must have mode 0700.'
unsafe=$(find "$private" \( ! -uid "$EUID" -o -perm /022 -o \( ! -type f -a ! -type d \) -o \( -type f -a -links +1 \) \) -print -quit)
[[ -z $unsafe ]] || die 'Installer setup must contain only operator-owned regular files and directories, without group/other write access, symlinks or hard-linked files.'
unsafe=$(find "$private" -type f ! -path "$private/extra-files/persist/etc/machine-id" -perm /077 -print -quit)
[[ -z $unsafe ]] || die 'Installer files other than payload machine-id must be owner-only.'

if [[ $prepare == true ]]; then
  umask 077
  ensure_directory() {
    local path="$private/$1" mode=$2
    if [[ ! -e $path ]]; then
      mkdir -m "$mode" -- "$path"
    fi
    [[ -d $path && $(stat -c %a "$path") == "$mode" ]] \
      || die "Existing setup directory has incorrect type or mode: $1 (expected $mode)."
  }
  for dir in extra-files extra-files/persist extra-files/persist/etc extra-files/persist/etc/ssh; do
    ensure_directory "$dir" 755
  done
  has_secrets=$(nix eval --no-update-lock-file --json \
    "$flake#nixosConfigurations.$host.config.sops.secrets" --apply 'secrets: secrets != {}')
  if [[ $has_secrets == true ]]; then
    for dir in extra-files/persist/var extra-files/persist/var/lib; do
      ensure_directory "$dir" 755
    done
    ensure_directory extra-files/persist/var/lib/sops-nix 700
  fi

  scratch=$(mktemp -d "$private/.prepare.XXXXXXXX")
  trap 'rm -rf -- "$scratch"' EXIT
  known_hosts_source=$(jq -r '.knownHostsFile // empty' <<<"$input")
  if [[ -n $known_hosts_source ]]; then
    source_path=$(realpath -e -- "$known_hosts_source")
    [[ $source_path == "$(realpath -ms -- "$known_hosts_source")" && -f $source_path && -O $source_path && -r $source_path ]] \
      || die 'knownHostsFile must be an operator-owned readable regular file without symlinks.'
    case "$source_path" in
      "$root"|"$root"/*|/nix/store|/nix/store/*) die 'knownHostsFile must be outside the checkout and Nix store.' ;;
    esac
    [[ -z $(find "$source_path" -perm /022 -print) ]] || die 'knownHostsFile must not be group/other writable.'
    cp -- "$source_path" "$scratch/known_hosts"
    chmod 600 "$scratch/known_hosts"
    awk '
      NF && $1 !~ /^#/ { if (NF < 3 || $2 != "ssh-ed25519") exit 1; count++ }
      END { if (count != 1) exit 1 }
    ' "$scratch/known_hosts" \
      || die 'knownHostsFile must contain exactly one console-verified ED25519 known_hosts entry, not a bare public key.'
    ssh-keygen -lf "$scratch/known_hosts" >/dev/null 2>&1 \
      || die 'knownHostsFile contains an invalid public key.'
  fi

  ensure_key() {
    local key="$private/$1" public existing
    if [[ ! -e $key ]]; then
      [[ ! -e $key.pub ]] || die "Public key exists without its private key; restore it rather than rotate: $1"
      ssh-keygen -q -t ed25519 -N '' -C '' -f "$scratch/key"
      chmod 600 "$scratch/key" "$scratch/key.pub"
      ln -T -- "$scratch/key" "$key"
      rm -- "$scratch/key" "$scratch/key.pub"
      printf 'Generated missing key: %s\n' "$1"
    fi
    [[ -f $key && -s $key && $(stat -c %a "$key") == 600 ]] \
      || die "Existing private key must be nonempty with mode 0600: $1"
    public=$(ssh-keygen -y -P '' -f "$key" 2>/dev/null | awk '{ print $1 " " $2 }') \
      || die "Private key must be valid and usable without a passphrase: $1"
    if [[ ! -e $key.pub ]]; then
      printf '%s\n' "$public" > "$scratch/public"
      ln -T -- "$scratch/public" "$key.pub"
      rm -- "$scratch/public"
    fi
    [[ -f $key.pub && $(stat -c %a "$key.pub") == 600 ]] \
      || die "Public key must have mode 0600: $1.pub"
    existing=$(awk '{ print $1 " " $2 }' "$key.pub")
    [[ $existing == "$public" ]] || die "Public/private key mismatch; existing files were preserved: $1"
  }
  ensure_key identity
  ensure_key extra-files/persist/etc/ssh/ssh_host_ed25519_key

  machine_id="$private/extra-files/persist/etc/machine-id"
  if [[ ! -e $machine_id ]]; then
    python3 -c 'import secrets; print(secrets.token_hex(16))' > "$scratch/machine-id"
    chmod 444 "$scratch/machine-id"
    ln -T -- "$scratch/machine-id" "$machine_id"
    rm -- "$scratch/machine-id"
    printf 'Generated missing machine-id.\n'
  fi
  [[ -f $machine_id && $(stat -c %a "$machine_id") == 444 ]] \
    || die 'Existing machine-id must be a regular file with mode 0444.'
  value=$(<"$machine_id")
  [[ $value =~ ^[0-9a-f]{32}$ && $value != 00000000000000000000000000000000 ]] \
    || die 'Existing machine-id is invalid; restore it rather than replacing it automatically.'

  if [[ -n $known_hosts_source ]]; then
    mv -T -- "$scratch/known_hosts" "$private/known_hosts"
    printf 'Imported operator-supplied known_hosts; console verification remains your responsibility.\n'
  fi
  reviewed_digest=$(jq -r '.reviewedDiskoSha256 // empty' <<<"$input")
  if [[ -n $reviewed_digest ]]; then
    printf '%s\n' "$reviewed_digest" > "$scratch/disko.sha256"
    mv -T -- "$scratch/disko.sha256" "$private/disko.sha256"
    printf 'Recorded operator-supplied disko digest; installation still compares it with the built script.\n'
  fi
  for file in known_hosts disko.sha256; do
    if [[ ! -e $private/$file ]]; then
      : > "$scratch/empty"
      ln -T -- "$scratch/empty" "$private/$file"
      rm -- "$scratch/empty"
    fi
    [[ -f $private/$file && $(stat -c %a "$private/$file") == 600 ]] \
      || die "Setup file must be a regular file with mode 0600: $file"
    if [[ ! -s $private/$file ]]; then
      printf 'Pending operator review: %s is empty; installation will refuse it.\n' "$file"
    fi
  done
  if [[ $has_secrets == true && ! -s $private/extra-files/persist/var/lib/sops-nix/key.txt ]]; then
    printf 'Pending: import the reviewed age identity as extra-files/persist/var/lib/sops-nix/key.txt (0600); none was generated.\n'
  fi
  printf 'Local preparation only: %s\nAuthorize identity.pub on the live installer through its console; configure the verified %s-installer SSH alias manually.\nNo SSH, installation or reboot was performed. Preserve independent identity backups and complete the storage skill preflight.\n' "$private" "$host"
  exit 0
fi
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
