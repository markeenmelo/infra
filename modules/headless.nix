{ config, ... }:
{
  flake.modules.nixos.headless = {
    imports = [ config.flake.modules.nixos.ssh ];
  };
}
