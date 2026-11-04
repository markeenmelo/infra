{ config, ... }:
{
  fleet.hosts.racknerd.module = {
    imports = with config.flake.modules.nixos; [ server ];
    system.stateVersion = "26.05";
  };
}
