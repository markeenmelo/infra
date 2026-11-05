{ config, lib, ... }:
let
  carry = lib.mapAttrs (_: nixos: nixos.config.fleet.carry) config.flake.nixosConfigurations;
in
{
  flake.modules.nixos.base = {
    options.fleet.carry = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Paths relative to /persist that a reinstall copies from the old disk, because they are an identity or a key nothing else holds.";
    };
  };

  perSystem =
    { pkgs, ... }:
    {
      apps.install = {
        meta.description = "install HOST TARGET ROOT: from an installer image on TARGET, carry HOST's identity paths out of the old persist tree mounted at ROOT, unmount it, then partition with disko and install HOST's configuration";
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
            extra=$(mktemp -d)
            trap 'rm -rf "$extra"' EXIT
            mkdir -p "$extra/persist"
            ssh "$target" tar -C "$root" -chf - "''${paths[@]}" | tar -C "$extra/persist" -xf -
            cp -a "$extra/persist/." "$extra/"
            mount=$(ssh "$target" findmnt -n -o TARGET -T "$root")
            [ "$mount" != / ] || { echo "install: $root is on the installer's root, not a mounted old disk" >&2; exit 1; }
            trap - EXIT
            ssh "$target" umount -R "$mount"
            nixos-anywhere --flake ".#$host" --extra-files "$extra" --target-host "$target" || {
              echo "install: failed after the old disk was unmounted; identity kept in $extra, rerun nixos-anywhere with --extra-files $extra" >&2
              exit 1
            }
            rm -rf "$extra"
          '';
        };
      };
    };
}
