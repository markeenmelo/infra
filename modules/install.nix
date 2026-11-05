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
            trap 'rm -rf "$extra"' EXIT
            mkdir -p "$extra/persist"
            ssh "$target" tar -C "$root" -chf - etc/ssh/ssh_host_ed25519_key etc/ssh/ssh_host_ed25519_key.pub var/lib/tailscale |
              tar -C "$extra/persist" -xf -
            ssh "$target" umount -R "$(ssh "$target" findmnt -n -o TARGET -T "$root")"
            nixos-anywhere --flake ".#$host" --extra-files "$extra" --target-host "$target"
          '';
        };
      };
    };
}
