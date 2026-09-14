#!/usr/bin/env bash
set -Eeuo pipefail

step='task inputs'
hint='Use the locked devenv CLI and one fleet hostname. Preparation inputs require prepare=true. authorizeKey=true additionally requires bootstrapIdentityFile and explicitly contacts the live installer.'
die() {
  printf '\nERROR: %s\nTroubleshoot: %s\nProcedure: .agents/skills/storage/SKILL.md\n' "$1" "${2:-$hint}" >&2
  exit 1
}
trap 'die "Command failed during $step (exit $?)."' ERR

input=${DEVENV_TASK_INPUT:-'{}'}
usage='Use fleet:install --input host=HOST [--input prepare=true [--input installerHost=ADDRESS --input installerHostKey="ssh-ed25519 PUBLIC_KEY" [--input installerPort=22]] [--input authorizeKey=true --input bootstrapIdentityFile=/PATH] [--input knownHostsFile=/PATH] [--input reviewedDiskoSha256=DIGEST]].'
[[ $# == 0 ]] || die "$usage"
jq -e '
  type == "object" and
  ((keys - ["host", "prepare", "knownHostsFile", "reviewedDiskoSha256",
            "installerHost", "installerPort", "installerHostKey", "authorizeKey", "bootstrapIdentityFile"]) | length == 0) and
  (.host | type == "string" and test("^[a-z][a-z0-9-]*$")) and
  ((has("prepare") | not) or (.prepare | type == "boolean")) and
  ((has("knownHostsFile") | not) or (.knownHostsFile | type == "string" and startswith("/"))) and
  ((has("reviewedDiskoSha256") | not) or (.reviewedDiskoSha256 | type == "string" and test("^[0-9a-f]{64}$"))) and
  ((has("installerHost") | not) or (.installerHost | type == "string" and test("^[a-zA-Z0-9:][a-zA-Z0-9.:-]*$"))) and
  ((has("installerPort") | not) or (.installerPort | type == "number" and . == floor and . >= 1 and . <= 65535)) and
  ((has("installerHostKey") | not) or (.installerHostKey | type == "string" and test("^ssh-ed25519 [A-Za-z0-9+/]+={0,2}$"))) and
  (has("installerHost") == has("installerHostKey")) and
  ((has("installerPort") | not) or has("installerHost")) and
  ((has("installerHostKey") and has("knownHostsFile")) | not) and
  ((has("authorizeKey") | not) or (.authorizeKey | type == "boolean")) and
  ((has("bootstrapIdentityFile") | not) or (.bootstrapIdentityFile | type == "string" and startswith("/"))) and
  (has("bootstrapIdentityFile") == (.authorizeKey == true)) and
  (((keys - ["host", "prepare"]) | length == 0) or .prepare == true)
' <<<"$input" >/dev/null 2>&1 || die "$usage"
host=$(jq -r '.host' <<<"$input")
prepare=$(jq -r '.prepare // false' <<<"$input")

step='fleet host lookup'
hint='Check the Nix error above and the host name. Use nix run --no-update-lock-file .#devenv -- tasks run fleet:install --input host=HOST --input prepare=true. Installation, unlike preparation, requires a clean reviewed commit.'
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

step='installer directory checks'
hint='Inspect ownership and modes with stat. Use an absolute XDG_DATA_HOME outside Git and /nix/store, without symlinks. The host setup directory must be operator-owned and 0700; keys must be owner-only. Fix only reviewed paths, never use recursive chmod or delete identities to make checks pass.'
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

alias="$host-installer"
ssh_options=(
  "UserKnownHostsFile=$private/known_hosts"
  GlobalKnownHostsFile=/dev/null KnownHostsCommand=none VerifyHostKeyDNS=no
  StrictHostKeyChecking=yes UpdateHostKeys=no HostKeyAlgorithms=ssh-ed25519
  CanonicalizeHostname=no ControlMaster=no ControlPath=none
  BatchMode=yes PreferredAuthentications=publickey PasswordAuthentication=no
  KbdInteractiveAuthentication=no IdentityAgent=none IdentitiesOnly=yes
  ForwardAgent=no ClearAllForwardings=yes
  ConnectTimeout=15 ServerAliveInterval=10 ServerAliveCountMax=3
)
load_installer_config() {
  local path=$1 connection
  [[ -f $path && $(stat -c %a "$path") == 600 ]] \
    || die 'Managed ssh_config must be a regular file with mode 0600.'
  connection=$(python3 - "$path" "$alias" <<'PY'
import ipaddress
import re
import sys

with open(sys.argv[1], "rb") as source:
    content = source.read(1024)
match = re.fullmatch(
    rb"Host " + re.escape(sys.argv[2].encode()) +
    rb"\n  HostName ([a-zA-Z0-9:][a-zA-Z0-9.:-]{0,252})\n  Port ([1-9][0-9]{0,4})\n", content,
)
if not match or not 1 <= int(match[2]) <= 65535:
    sys.exit("Invalid managed ssh_config; regenerate it with installerHost and installerHostKey.")
hostname = match[1].decode()
if ":" in hostname:
    try:
        ipaddress.IPv6Address(hostname)
    except ValueError:
        sys.exit("installerHost must be a hostname or unbracketed IP address; supply installerPort separately.")
print(hostname)
print(int(match[2]))
PY
  ) || die 'Managed ssh_config is not a task-generated endpoint configuration.'
  installer_hostname=${connection%$'\n'*}
  installer_port=${connection##*$'\n'}
  known_host_target=$installer_hostname
  if [[ $installer_port != 22 ]]; then
    known_host_target="[$installer_hostname]:$installer_port"
  fi
}

if [[ $prepare == true ]]; then
  umask 077
  ensure_directory() {
    local path="$private/$1" mode=$2
    if [[ ! -e $path ]]; then
      mkdir -m "$mode" -- "$path"
    fi
    [[ -d $path && $(stat -c %a "$path") == "$mode" ]] \
      || die "Existing setup directory has incorrect type or mode: $1 (expected $mode)." \
        "Inspect $1 with stat and correct only that directory to mode $mode after confirming ownership. Do not chmod the payload recursively."
  }
  for dir in extra-files extra-files/persist extra-files/persist/etc extra-files/persist/etc/ssh; do
    ensure_directory "$dir" 755
  done
  step='host secret-selection lookup'
  hint='Check the Nix error above using the locked CLI. This lookup only determines whether an age identity is required; no private file is passed to Nix.'
  has_secrets=$(nix eval --no-update-lock-file --json \
    "$flake#nixosConfigurations.$host.config.sops.secrets" --apply 'secrets: secrets != {}')
  for dir in extra-files/persist/var extra-files/persist/var/lib; do
    if [[ $has_secrets == true || -e $private/$dir ]]; then
      ensure_directory "$dir" 755
    fi
  done
  if [[ $has_secrets == true ]]; then
    ensure_directory extra-files/persist/var/lib/sops-nix 700
  fi

  step='local preparation workspace'
  hint='Check local free space and write access to the private host setup directory. Do not change permissions recursively or remove existing identities.'
  scratch=$(mktemp -d "$private/.prepare.XXXXXXXX")
  trap 'rm -rf -- "$scratch"' EXIT
  valid_known_hosts() {
    awk '
      NF && $1 !~ /^#/ { if (NF < 3 || $2 != "ssh-ed25519") exit 1; count++ }
      END { if (count != 1) exit 1 }
    ' "$1" || return 1
    ssh-keygen -lf /dev/stdin < "$1" 2>/dev/null | grep -q ' (ED25519)$'
  }
  known_hosts_hint='Read the live installer ED25519 public key and fingerprint through the verified console. Supply installerHost and installerHostKey="ssh-ed25519 PUBLIC_KEY" to generate private ssh_config and known_hosts, or import one full known_hosts entry with knownHostsFile=/ABSOLUTE/PATH. Never use a private key, disable strict checking or trust a scan alone.'
  digest_hint='Build and read the disko script using the storage skill, then record only its 64-character lowercase SHA-256 digest via --input reviewedDiskoSha256=DIGEST. Do not paste the filename from sha256sum. Preparation checks the format only; installation compares it with the built script.'
  age_hint='Restore the reviewed age identity from independent backup to extra-files/persist/var/lib/sops-nix/key.txt (0600, operator-owned; parent 0700). Do not generate a replacement or print the private key. Syntax validation does not prove the recipient matches or secrets decrypt.'
  step='known_hosts import'
  hint=$known_hosts_hint
  known_hosts_source=$(jq -r '.knownHostsFile // empty' <<<"$input")
  if [[ -n $known_hosts_source ]]; then
    source_path=$(realpath -e -- "$known_hosts_source")
    [[ $source_path == "$(realpath -ms -- "$known_hosts_source")" ]] \
      || die 'knownHostsFile must not contain symlinks.'
    case "$source_path" in
      "$root"|"$root"/*|/nix/store|/nix/store/*) die 'knownHostsFile must be outside the checkout and Nix store.' ;;
    esac
    python3 - "$source_path" "$scratch/known_hosts" <<'PY'
import os
import shutil
import stat
import sys

source_path, destination = sys.argv[1:]
directory_flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
directory = os.open("/", directory_flags)
try:
    for component in source_path.split("/")[1:-1]:
        child = os.open(component, directory_flags, dir_fd=directory)
        os.close(directory)
        directory = child
    descriptor = os.open(
        os.path.basename(source_path), os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK,
        dir_fd=directory,
    )
    with os.fdopen(descriptor, "rb") as source:
        metadata = os.fstat(source.fileno())
        if (not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != os.geteuid()
                or metadata.st_mode & 0o022 or metadata.st_nlink != 1):
            sys.exit("knownHostsFile must be an operator-owned, single-link regular file without group/other write access.")
        with open(destination, "xb") as target:
            shutil.copyfileobj(source, target)
except OSError as error:
    sys.exit(f"Cannot safely import knownHostsFile: {error.strerror}.")
finally:
    os.close(directory)
PY
    chmod 600 "$scratch/known_hosts"
    valid_known_hosts "$scratch/known_hosts" \
      || die 'knownHostsFile must contain exactly one valid ED25519 known_hosts entry, not a bare public key.'
  fi

  if jq -e 'has("installerHost")' <<<"$input" >/dev/null; then
    step='installer endpoint and console host key'
    hint=$known_hosts_hint
    installer_hostname=$(jq -r '.installerHost' <<<"$input")
    installer_port=$(jq -r '.installerPort // 22' <<<"$input")
    printf 'Host %s\n  HostName %s\n  Port %s\n' "$alias" "$installer_hostname" "$installer_port" > "$scratch/ssh_config"
    load_installer_config "$scratch/ssh_config"
    installer_host_key=$(jq -r '.installerHostKey' <<<"$input")
    printf '%s %s\n' "$known_host_target" "$installer_host_key" > "$scratch/known_hosts"
    valid_known_hosts "$scratch/known_hosts" || die 'installerHostKey must be a valid ED25519 public host key.'
    printf 'Console-supplied installer host key (compare with the console):\n'
    ssh-keygen -lf "$scratch/known_hosts"
  fi

  ensure_key() {
    local key="$private/$1" public existing
    step="SSH key checks: $1"
    hint='Inspect permissions without displaying private contents (private/public files 0600). Restore the intended matching key pair from backup if invalid; do not remove a private key to force regeneration. The client identity must work without an agent or passphrase. Check local free space if generation fails.'
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
    if [[ $1 == extra-files/persist/etc/ssh/ssh_host_ed25519_key ]]; then
      [[ $public == ssh-ed25519\ * ]] || die 'The installed-system host key must be ED25519.'
    fi
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

  step='machine-id checks'
  hint='Restore the intended machine-id from backup on reinstalls: 32 lowercase hexadecimal characters, not all zero, with at most one trailing newline, in a regular file with mode 0444. Never replace an existing identity merely to make validation pass.'
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
  if ! python3 - "$machine_id" <<'PY'
import re
import sys

with open(sys.argv[1], "rb") as source:
    value = source.read(34)
sys.exit(0 if re.fullmatch(rb"[0-9a-f]{32}\n?", value) and value[:32] != b"0" * 32 else 1)
PY
  then
    die 'Existing machine-id is invalid; restore it rather than replacing it automatically.'
  fi

  step='known_hosts update'
  hint=$known_hosts_hint
  if [[ -e $scratch/known_hosts ]]; then
    mv -T -- "$scratch/known_hosts" "$private/known_hosts"
    printf 'Recorded console-supplied known_hosts; console verification remains your responsibility.\n'
  fi
  if [[ -e $scratch/ssh_config ]]; then
    mv -T -- "$scratch/ssh_config" "$private/ssh_config"
    printf 'Configured private installer alias: %s (no changes to ~/.ssh/config).\n' "$private/ssh_config"
  fi
  step='disko digest update'
  hint=$digest_hint
  reviewed_digest=$(jq -r '.reviewedDiskoSha256 // empty' <<<"$input")
  if [[ -n $reviewed_digest ]]; then
    printf '%s\n' "$reviewed_digest" > "$scratch/disko.sha256"
    mv -T -- "$scratch/disko.sha256" "$private/disko.sha256"
    printf 'Recorded operator-supplied disko digest; installation still compares it with the built script.\n'
  fi
  issues=0
  report_issue() {
    printf '\nBLOCKED: %s\nTroubleshoot: %s\n' "$1" "$2" >&2
    issues=$((issues + 1))
  }
  for file in known_hosts disko.sha256; do
    step="required installer file: $file"
    if [[ $file == known_hosts ]]; then hint=$known_hosts_hint; else hint=$digest_hint; fi
    if [[ ! -e $private/$file ]]; then
      : > "$scratch/empty"
      ln -T -- "$scratch/empty" "$private/$file"
      rm -- "$scratch/empty"
    fi
    if [[ ! -f $private/$file || ! -r $private/$file || $(stat -c %a "$private/$file") != 600 ]]; then
      report_issue "$file must be a readable regular file with mode 0600." "Inspect its type, ownership and mode with stat; correct only that reviewed path. $hint"
    elif [[ ! -s $private/$file ]]; then
      report_issue "$file is empty; installation will refuse it." "$hint"
    elif [[ $file == known_hosts ]]; then
      if ! valid_known_hosts "$private/$file"; then
        report_issue 'known_hosts must contain exactly one valid ED25519 known_hosts entry, not a bare public key.' "$hint"
      fi
    else
      value=$(<"$private/$file")
      if [[ ! $value =~ ^[0-9a-f]{64}$ ]]; then
        report_issue 'disko.sha256 has an invalid digest format.' "$hint"
      fi
    fi
  done
  if [[ $has_secrets == true ]]; then
    step='age identity checks'
    hint=$age_hint
    age_identity="$private/extra-files/persist/var/lib/sops-nix/key.txt"
    if [[ ! -f $age_identity || ! -r $age_identity || ! -s $age_identity ]]; then
      report_issue 'This host requires a readable, nonempty age identity file; none was generated.' "$hint"
    elif [[ $(stat -c %a "$age_identity") != 600 ]]; then
      report_issue 'The age identity file must have mode 0600.' "$hint"
    elif ! age-keygen -y "$age_identity" >/dev/null 2>&1; then
      report_issue 'The age identity file is not a valid native age identity.' "$hint"
    fi
  fi
  if [[ -e $private/ssh_config ]]; then
    step='managed installer connection checks'
    hint=$known_hosts_hint
    load_installer_config "$private/ssh_config"
    if ! ssh-keygen -F "$known_host_target" -f "$private/known_hosts" >/dev/null; then
      report_issue 'known_hosts does not pin the managed installer endpoint and port.' "$hint"
    fi
  fi
  printf 'Installer setup: %s\n' "$private"
  [[ $issues == 0 ]] || die "$issues installer-file checks failed; generated files were kept. No SSH was performed." \
    'Follow the BLOCKED items above, then rerun prepare=true. Existing identities are preserved; preparation never starts installation.'
  printf 'Local installer-file checks passed. Console trust, disk state, disko review/digest equality, backups and decryption remain operator responsibilities.\n'

  if [[ $(jq -r '.authorizeKey // false' <<<"$input") == true ]]; then
    step='bootstrap identity checks'
    hint='Use a private, operator-owned, single-link key outside Git/store without symlinks, mode 0600 or 0400, usable without a passphrase. Every parent directory must be root/operator-owned without group/other write access; shared temporary directories are refused. It must already authorize root on the console-verified live installer. No password or agent fallback is allowed.'
    [[ -e $private/ssh_config ]] || die 'Key authorization requires managed ssh_config; supply installerHost and installerHostKey first.'
    bootstrap=$(jq -r '.bootstrapIdentityFile' <<<"$input")
    resolved=$(realpath -e -- "$bootstrap")
    [[ $resolved == "$(realpath -ms -- "$bootstrap")" ]] || die 'bootstrapIdentityFile must not contain symlinks.'
    case "$resolved" in
      "$root"|"$root"/*|/nix/store|/nix/store/*) die 'bootstrapIdentityFile must be outside Git and the Nix store.' ;;
    esac
    [[ $resolved =~ ^/[a-zA-Z0-9/._+-]+$ ]] || die 'Unsafe bootstrapIdentityFile path.'
    python3 - "$resolved" <<'PY'
import os
import sys

flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
directory = None
try:
    for component in ["/", *sys.argv[1].split("/")[1:-1]]:
        child = os.open(component, flags, dir_fd=directory)
        if directory is not None:
            os.close(directory)
        directory = child
        metadata = os.fstat(directory)
        if metadata.st_uid not in (0, os.geteuid()) or metadata.st_mode & 0o022:
            sys.exit("bootstrapIdentityFile ancestors must be root/operator-owned without group/other write access.")
except OSError as error:
    sys.exit(f"Cannot safely inspect bootstrapIdentityFile ancestors: {error.strerror}.")
finally:
    if directory is not None:
        os.close(directory)
PY
    [[ -f $resolved && ! -L $resolved && -O $resolved && $(stat -c %h "$resolved") == 1 ]] \
      || die 'Unsafe bootstrapIdentityFile type, owner or link count.'
    mode=$(stat -c %a "$resolved")
    [[ $mode == 600 || $mode == 400 ]] || die 'bootstrapIdentityFile must have mode 0600 or 0400.'
    ssh-keygen -y -P '' -f "$resolved" >/dev/null 2>&1 || die 'Bootstrap key must be valid and usable noninteractively.'
    ssh_args=(-F "$private/ssh_config" -T)
    for option in "${ssh_options[@]}"; do ssh_args+=(-o "$option"); done
    ssh_args+=(-o CertificateFile=none)
    client_public=$(awk '{ print $1 " " $2 }' "$private/identity.pub")
    step='explicit live-installer key authorization'
    hint='Stop on SSH or installer-guard failure. Verify the endpoint and console host key, existing root key access, and an idle NixOS live installer. Do not relax SSH policy or retry an uncertain remote write blindly.'
    printf 'Authorizing generated client key on root@%s using existing verified key access. No disk operations or installation.\n' "$alias"
    ssh "${ssh_args[@]}" -i "$resolved" "root@$alias" '
set -eu
[ "$(id -u)" = 0 ] && grep -Eq "^ID=\"?nixos\"?$" /etc/os-release &&
  grep -Eq "^VARIANT_ID=\"?installer\"?$" /etc/os-release || {
  echo "Refusing key upload: target is not a root NixOS live-installer session." >&2; exit 1;
}
case "$(findmnt -n -o FSTYPE /)" in
  overlay|tmpfs) ;;
  *) echo "Refusing key upload: installer root is not overlay/tmpfs." >&2; exit 1 ;;
esac
IFS= read -r key
[ ! -L /root ] && [ -d /root ] && [ "$(stat -c %u /root)" = 0 ] || exit 1
[ "$((0$(stat -c %a /root) & 022))" -eq 0 ] || exit 1
[ "$(findmnt -n -o TARGET -T /root)" = / ] || {
  echo "Refusing key upload: /root is mounted separately from the live installer root." >&2; exit 1;
}
umask 077
if [ ! -e /root/.ssh ] && [ ! -L /root/.ssh ]; then mkdir -m 700 /root/.ssh; fi
[ ! -L /root/.ssh ] && [ -d /root/.ssh ] && [ "$(stat -c %u:%a /root/.ssh)" = 0:700 ] || {
  echo "Unsafe /root/.ssh; refusing to change existing permissions." >&2; exit 1;
}
[ "$(findmnt -n -o TARGET -T /root/.ssh)" = / ] || exit 1
authorized=/root/.ssh/authorized_keys
if [ ! -e "$authorized" ] && [ ! -L "$authorized" ]; then (set -C; : > "$authorized"); fi
[ ! -L "$authorized" ] && [ -f "$authorized" ] && [ "$(stat -c %u:%a:%h "$authorized")" = 0:600:1 ] || {
  echo "Unsafe authorized_keys; refusing to replace it or change permissions." >&2; exit 1;
}
[ "$(findmnt -n -o TARGET -T "$authorized")" = / ] || exit 1
if ! grep -qxF -- "$key" "$authorized"; then
  if grep -qF -- "${key#* }" "$authorized"; then
    echo "Key already has a different authorized_keys entry; review restrictions at the console." >&2; exit 1
  fi
  printf "\n%s\n" "$key" >> "$authorized"
fi
printf "Installer client public key authorized; existing entries preserved.\n"
' <<< "$client_public"
    step='generated installer key login verification'
    hint='The public key may already have been uploaded. Inspect console access and authorized_keys; do not retry blindly or broaden permissions. No installation has started.'
    ssh "${ssh_args[@]}" -n -i "$private/identity" "root@$alias" '
set -eu
[ "$(id -u)" = 0 ]
grep -Eq "^ID=\"?nixos\"?$" /etc/os-release
grep -Eq "^VARIANT_ID=\"?installer\"?$" /etc/os-release
case "$(findmnt -n -o FSTYPE /)" in overlay|tmpfs) ;; *) exit 1 ;; esac
printf "Generated installer key login verified.\n"
'
  else
    printf 'No SSH was performed. To upload identity.pub explicitly, use authorizeKey=true with bootstrapIdentityFile=/PATH (requires managed ssh_config), or authorize it through the console.\n'
  fi
  if [[ ! -e $private/ssh_config ]]; then
    printf 'No managed ssh_config: supply installerHost and installerHostKey, or configure the verified %s alias manually.\n' "$alias"
  fi
  printf 'Preparation finished; no disk operations, installation or reboot. Complete the storage skill live-disk preflight separately.\n'
  exit 0
fi
step='installation prerequisites'
hint='Stop before installation. Run prepare=true to validate the local installer files and follow its troubleshooting output; complete the live-installer review in the storage skill separately.'
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

installer_config_args=()
if [[ -e $private/ssh_config ]]; then
  load_installer_config "$private/ssh_config"
  ssh-keygen -F "$known_host_target" -f "$private/known_hosts" >/dev/null \
    || die 'known_hosts does not pin the managed installer endpoint and port.'
  hostname=$installer_hostname
  installer_config_args=(--ssh-config "$private/ssh_config")
else
  hostname=$(ssh -G -o CanonicalizeHostname=no "root@$alias" | awk '$1 == "hostname" { print $2 }')
  [[ -n $hostname && $hostname != "$alias" ]] || die "Prepare installerHost and installerHostKey, or configure the verified HostName for $alias first."
fi

disko=$(nix build --no-update-lock-file --no-link --print-out-paths \
  "$flake#nixosConfigurations.$host.config.system.build.diskoScript")
system=$(nix build --no-update-lock-file --no-link --print-out-paths \
  "$flake#nixosConfigurations.$host.config.system.build.toplevel")
actual=$(sha256sum "$disko")
[[ ${actual%% *} == "$expected" ]] || die 'Disko script differs from the reviewed digest; review it again before installation.'

for option in "${ssh_options[@]}"; do installer_config_args+=(--ssh-option "$option"); done
printf 'Destructive install: %s via root@%s (%s). No kexec or reboot.\n' "$host" "$alias" "$hostname"
exec nixos-anywhere \
  --store-paths "$disko" "$system" \
  --target-host "root@$alias" \
  --phases disko,install --build-on local \
  -i "$private/identity" --extra-files "$private/extra-files" \
  "${installer_config_args[@]}"
