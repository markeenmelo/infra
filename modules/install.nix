{
  perSystem =
    { pkgs, ... }:
    {
      apps.install = {
        meta.description = "install HOST TARGET [ROOT]: partition TARGET with disko and install HOST's configuration, carrying its SSH host key and tailnet state over from ROOT on the target (default /, or the old persist tree mounted from an installer)";
        program = pkgs.writeShellApplication {
          name = "install";
          runtimeInputs = [
            pkgs.nixos-anywhere
            pkgs.openssh
          ];
          text = ''
            host=$1
            target=$2
            root=''${3:-/}
            extra=$(mktemp -d)
            trap 'rm -rf "$extra"' EXIT
            mkdir -p "$extra/persist"
            ssh "$target" tar -C "$root" -chf - etc/ssh/ssh_host_ed25519_key etc/ssh/ssh_host_ed25519_key.pub var/lib/tailscale |
              tar -C "$extra/persist" -xf -
            nixos-anywhere --flake ".#$host" --extra-files "$extra" --target-host "$target"
          '';
        };
      };
    };
}
