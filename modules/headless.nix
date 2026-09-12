{ config, ... }:
{
  flake.modules.nixos.headless = {
    imports = [ config.flake.modules.nixos.ssh ];
    # Do not import upstream profiles/headless.nix: it removes console and
    # emergency recovery. Headless here means no graphical session (the upstream
    # default target), not no console. Time synchronization is the upstream
    # default and documentation policy lives in base, so a graphical workstation
    # retains them without composing this headless target.
  };
}
