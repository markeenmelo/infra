{ config, ... }:
{
  flake.modules.nixos.headless = {
    imports = [ config.flake.modules.nixos.ssh ];
    # Do not import upstream profiles/headless.nix: it removes console and
    # emergency recovery. Here headless means no graphical session, not no console.
    systemd.defaultUnit = "multi-user.target";
    # Time synchronization and documentation policy live in base so a graphical
    # workstation retains them without composing this headless target.
  };
}
