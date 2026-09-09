{ config, ... }:
{
  flake.modules.nixos.headless = {
    imports = [ config.flake.modules.nixos.ssh ];
    # Do not import upstream profiles/headless.nix: it removes console and
    # emergency recovery. Here headless means no graphical session, not no console.
    systemd.defaultUnit = "multi-user.target";
    services.timesyncd.enable = true;
    documentation.nixos.enable = false;
    # VPN, reverse proxy, launchers and graphical sessions are separate future work.
  };
}
