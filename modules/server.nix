{ config, ... }:
{
  flake.modules.nixos.server = {
    imports = [ config.flake.modules.nixos.ssh ];
    documentation.nixos.enable = false;
    fleet.logging.persistent = true;
  };
}
