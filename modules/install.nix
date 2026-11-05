{
  perSystem =
    { pkgs, ... }:
    {
      apps.install = {
        meta.description = "install HOST TARGET ROOT: from an installer image on TARGET, carry the SSH host key and tailnet state out of the old persist tree mounted at ROOT, unmount it, then partition with disko and install HOST's configuration";
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
            extra=$(mktemp -d)
            mkdir -p "$extra/persist"
            ssh "$target" tar -C "$root" -chf - etc/ssh/ssh_host_ed25519_key etc/ssh/ssh_host_ed25519_key.pub var/lib/tailscale |
              tar -C "$extra/persist" -xf -
            mount=$(ssh "$target" findmnt -n -o TARGET -T "$root")
            [ "$mount" != / ] || { echo "install: $root is on the installer's root, not a mounted old disk" >&2; exit 1; }
            ssh "$target" umount -R "$mount"
            nixos-anywhere --flake ".#$host" --extra-files "$extra" --target-host "$target" ||
              { echo "install: failed after the old disk was unmounted; identity kept in $extra, rerun nixos-anywhere with --extra-files $extra" >&2; exit 1; }
            rm -rf "$extra"
          '';
        };
      };
    };
}
