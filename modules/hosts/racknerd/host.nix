{ config, ... }:
{
  fleet.hosts.racknerd.module = {
    imports = with config.flake.modules.nixos; [
      server
      edge
    ];
    system.stateVersion = "26.05";
  };
}
