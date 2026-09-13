#!/usr/bin/env bash
set -euo pipefail
if [[ $- == *x* ]]; then set +x; echo 'Refusing installation with shell tracing.' >&2; exit 1; fi
cd "${DEVENV_ROOT:?Enter the locked devenv shell}"
[[ $# == 0 ]] || { echo 'Use host:install task inputs.' >&2; exit 1; }
input=${DEVENV_TASK_INPUT:-\{\}}
jq -e 'type == "object" and keys == ["confirm","device","fingerprint","host","identity","planHash","port","target"]
  and (.host | type == "string" and test("^[a-z][a-z0-9-]*$"))
  and (.target | type == "string" and test("^root@[a-zA-Z0-9][a-zA-Z0-9.-]*$"))
  and (.port | type == "number" and floor == . and . > 0 and . < 65536)
  and (.device | type == "string" and test("^/dev/disk/by-(id|path)/[a-zA-Z0-9._:+-]+$") and (test("-part[0-9]+$") | not))
  and (.identity | type == "string" and length > 0 and length < 129 and (test("[[:cntrl:]]") | not))
  and (.fingerprint | type == "string" and test("^SHA256:[A-Za-z0-9+/]{43}$"))
  and (.planHash | type == "string" and test("^[a-f0-9]{64}$"))
  and .confirm == ("ERASE " + .host + " " + .target + " " + .device + " " + .identity)' <<<"$input" >/dev/null 2>&1 || {
  echo 'Refusing: require host, root@installer, port, whole device, serial (Racknerd PCI: size:BYTES), console-verified ED25519 fingerprint, reviewed disko script SHA-256 planHash and exact ERASE confirmation.' >&2
  exit 1
}
if [[ -v SSH_PRIVATE_KEY || -v SSHPASS || -v LOCAL_KEY ]]; then
  echo 'Refusing inherited credential contents/signing; use private runtime path variables.' >&2
  exit 1
fi
[[ -z $(git status --porcelain) ]] || { echo 'Commit the reviewed candidate before installation.' >&2; exit 1; }
revision=$(git rev-parse HEAD)
host=$(jq -r '.host' <<<"$input")
python3 scripts/storage/check-staging.py "$host"
target=$(jq -r '.target' <<<"$input")
port=$(jq -r '.port' <<<"$input")
device=$(jq -r '.device' <<<"$input")
identity=$(jq -r '.identity' <<<"$input")
fingerprint=$(jq -r '.fingerprint' <<<"$input")
bash scripts/devenv/preflight.sh
bash scripts/fleet/ready.sh "$host" disk-plan
report=$(nix eval --no-update-lock-file --json ".#fleet.$host")
jq -e --arg device "$device" '.storageMode == "provision" and .osDisk == $device' <<<"$report" >/dev/null || {
  echo 'Refusing: confirmed disk differs from the commissioned OS layout.' >&2
  exit 1
}
if [[ $device == /dev/disk/by-path/* ]]; then
  [[ $host == racknerd && $device == /dev/disk/by-path/pci-* && $identity =~ ^size:[1-9][0-9]*$ ]] || {
    echo 'Only reviewed Racknerd PCI identity may use a size confirmation instead of a serial.' >&2
    exit 1
  }
fi
disko=$(nix build --no-update-lock-file --no-link --print-out-paths ".#nixosConfigurations.$host.config.system.build.diskoScript")
system=$(nix build --no-update-lock-file --no-link --print-out-paths ".#nixosConfigurations.$host.config.system.build.toplevel")
[[ $disko == /nix/store/* && $system == /nix/store/* && -f $disko && -d $system ]]
plan_hash=$(sha256sum "$disko" | cut -d ' ' -f1)
[[ $plan_hash == "$(jq -r '.planHash' <<<"$input")" ]] || { echo 'Refusing: generated disk plan differs from the reviewed SHA-256.' >&2; exit 1; }
umask 077
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cp -a "$FLEET_INSTALL_EXTRA_FILES" "$work/staging"
cp "$FLEET_INSTALL_MANIFEST" "$work/manifest.json"
export FLEET_INSTALL_EXTRA_FILES="$work/staging" FLEET_INSTALL_MANIFEST="$work/manifest.json"
python3 scripts/storage/check-staging.py "$host"
export FLEET_REAL_SSH
FLEET_REAL_SSH=$(readlink -f "$(command -v ssh)")
export FLEET_INSTALL_KNOWN_HOSTS="$work/known_hosts"
ssh-keyscan -T 15 -p "$port" -t ed25519 "${target#root@}" >"$FLEET_INSTALL_KNOWN_HOSTS" 2>/dev/null
actual=$(ssh-keygen -E sha256 -lf "$FLEET_INSTALL_KNOWN_HOSTS" | awk '{print $2}' | sort -u)
[[ $actual == "$fingerprint" ]] || { echo 'Refusing: installer host fingerprint mismatch.' >&2; exit 1; }
mkdir "$work/bin"
{
  printf '#!%s\n' "$BASH"
  printf 'source %q\n' "$PWD/scripts/storage/installer-ssh.sh"
} >"$work/bin/ssh"
chmod 0700 "$work/bin/ssh"
export PATH="$work/bin:$PATH"
inventory=$(ssh -p "$port" "$target" "bash -s -- '$device'" <scripts/storage/installer-inventory.sh)
jq -e --arg identity "$identity" --arg device "$device" '
  .blockdevices | type == "array" and length == 1 and .[0].type == "disk"
  and (.[0].size | type == "number" and . > 0)
  and (all(.[0] | recurse(.children[]?);
    (.type == "disk" or .type == "part")
    and (.mountpoints | type) == "array" and all(.mountpoints[]; . == null or . == "")
    and (if has("children") then (.children | type) == "array" else true end)))
  and (if ($device | startswith("/dev/disk/by-path/"))
    then ("size:" + (.[0].size | tostring)) == $identity
    else .[0].serial == $identity end)' <<<"$inventory" >/dev/null || {
  echo 'Refusing: fresh target disk type/consumer, serial/size or mounted-use check failed.' >&2
  exit 1
}
[[ -z $(git status --porcelain) && $(git rev-parse HEAD) == "$revision" ]] || { echo 'Candidate changed during preflight; refusing.' >&2; exit 1; }
printf 'Installing %s on its confirmed OS disk only; no kexec or reboot phase.\n' "$host"
nixos-anywhere --store-paths "$disko" "$system" --target-host "$target" --ssh-port "$port" \
  -i "$FLEET_INSTALL_IDENTITY" --extra-files "$FLEET_INSTALL_EXTRA_FILES" --phases disko,install --build-on local
printf 'Installer returned successfully. Inspect mounts/identities/boot setup and plan boot acceptance separately; no reboot requested.\n'
