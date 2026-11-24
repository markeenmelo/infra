{ config, lib, ... }:
let
  carry = lib.mapAttrs (_: nixos: nixos.config.fleet.carry) config.flake.nixosConfigurations;
  identities = ".config/sops/enroll";
in
{
  flake.modules.nixos.base = {
    options.fleet.carry = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Paths relative to /persist that a reinstall copies from the old disk, because they are an identity or a key nothing else holds.";
    };
  };

  perSystem =
    { config, pkgs, ... }:
    {
      apps.enroll = {
        meta.description = "enroll HOST: before a new host's first install, make its identity on this machine: an SSH host key, an initrd SSH host key and a tailnet login under its name, in a private directory beside the operator's sops key that an install takes as extra files; prints the age recipient, the tailnet address and the initrd host key its facts need";
        program = pkgs.writeShellApplication {
          name = "enroll";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.git
            pkgs.jq
            pkgs.openssh
            pkgs.ssh-to-age
            pkgs.tailscale
          ];
          text = ''
            [[ ''${1-} =~ ^[a-z][a-z0-9-]*$ ]] || { echo "enroll: name the new host" >&2; exit 1; }
            host=$1
            cd "$(git rev-parse --show-toplevel)"
            umask 077
            identity=$HOME/${identities}/$host
            [ ! -e "$identity" ] || { echo "enroll: $identity exists: install $host from it, or delete it to enroll again" >&2; exit 1; }
            mkdir -p "$HOME/${identities}"
            mkdir "$identity"
            run=$(mktemp -d)
            daemon=
            trap '[ -z "$daemon" ] || kill "$daemon" 2> /dev/null || true; rm -rf "$run" "$identity"' EXIT
            persist=$identity/persist
            install -d -m 755 "$persist" "$persist/etc" "$persist/etc/ssh" "$persist/etc/secrets" "$persist/var" "$persist/var/lib"
            install -d -m 700 "$persist/etc/secrets/initrd" "$persist/var/lib/tailscale"
            ssh-keygen -q -t ed25519 -N "" -C "$host" -f "$persist/etc/ssh/ssh_host_ed25519_key"
            ssh-keygen -q -t ed25519 -N "" -C "$host-initrd" -f "$persist/etc/secrets/initrd/ssh_host_ed25519_key"
            chmod 644 "$persist/etc/ssh/ssh_host_ed25519_key.pub"
            ${config.apps.tofu.program} tailscale output -json enrollment_keys | jq -er --arg host "$host" '.[$host]' > "$run/key"
            tailscaled --tun=userspace-networking --statedir="$persist/var/lib/tailscale" --socket="$run/tailscaled.sock" 2> "$run/log" &
            daemon=$!
            for _ in $(seq 100); do
              [ ! -S "$run/tailscaled.sock" ] || break
              sleep 0.1
            done
            [ -S "$run/tailscaled.sock" ] || {
              cat "$run/log" >&2
              echo "enroll: tailscaled did not start, so nothing is spent" >&2
              exit 1
            }
            trap 'kill "$daemon" 2> /dev/null || true; rm -rf "$run"; echo "enroll: failed where the enrollment key may already be spent; the identity is kept in $identity" >&2' EXIT
            tailscale --socket="$run/tailscaled.sock" up --auth-key="file:$run/key" --hostname="$host"
            address=$(tailscale --socket="$run/tailscaled.sock" ip -4)
            kill "$daemon"
            wait "$daemon" || true
            rm -rf "$run"
            trap - EXIT
            echo "age recipient:   $(ssh-to-age < "$persist/etc/ssh/ssh_host_ed25519_key.pub")"
            echo "tailnet address: $address"
            echo "initrd host key: $(cut -d ' ' -f 1,2 "$persist/etc/secrets/initrd/ssh_host_ed25519_key.pub")"
            echo "identity:        $identity, private keys: install takes it as ROOT; delete it once the host answers on the tailnet"
          '';
        };
      };
      apps.install = {
        meta.description = "install HOST TARGET ROOT: partition TARGET with disko and install HOST's configuration with its identity, either carried out of the old persist tree mounted at ROOT on an installer image, which is unmounted first, or, for a new host, taken from the local directory ROOT that enroll made";
        program = pkgs.writeShellApplication {
          name = "install";
          runtimeInputs = [
            pkgs.nixos-anywhere
            pkgs.openssh
          ];
          text = ''
            host=$1
            target=$2
            root=$3
            case $host in
            ${
              lib.concatStrings (
                lib.mapAttrsToList (name: paths: "  ${name}) paths=(${lib.escapeShellArgs paths}) ;;\n") carry
              )
            }  *) echo "install: no NixOS host named $host" >&2; exit 1 ;;
            esac
            kexec=()
            if [ -d "$root/persist" ]; then
              extra=$root
              kexec=(--kexec-extra-flags --kexec-syscall)
              for path in "''${paths[@]}"; do
                [ -e "$extra/persist/$path" ] || { echo "install: the identity in $extra lacks $path" >&2; exit 1; }
              done
            else
              extra=$(mktemp -d)
              echo "install: identity staged in $extra" >&2
              trap 'rm -rf "$extra"' EXIT
              mkdir -p "$extra/persist"
              ssh "$target" tar -C "''${root@Q}" -chf - "''${paths[@]@Q}" | tar -C "$extra/persist" -xf -
              cp -a "$extra/persist/." "$extra/"
              mount=$(ssh "$target" findmnt -n -o TARGET -T "''${root@Q}")
              [ "$mount" != / ] || { echo "install: $root is on the installer's root, not a mounted old disk" >&2; exit 1; }
              ssh "$target" umount -R "''${mount@Q}"
              trap - EXIT
            fi
            nixos-anywhere "''${kexec[@]}" --flake ".#$host" --extra-files "$extra" --target-host "$target" || {
              echo "install: nixos-anywhere failed; read above how far it got, since once it has partitioned, the target's old system is gone. The identity is kept in $extra: rerun nixos-anywhere with --extra-files $extra" >&2
              exit 1
            }
            if [ "$extra" = "$root" ]; then
              echo "install: $host has not booted yet and $extra is the only other copy of its identity; delete it once $host answers on the tailnet" >&2
            else
              rm -rf "$extra"
            fi
          '';
        };
      };
    };
}
