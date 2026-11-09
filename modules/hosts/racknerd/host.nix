{ config, ... }:
{
  fleet.hosts.racknerd.tailnetAddress = "100.96.133.3";
  fleet.hosts.racknerd.module = {
    imports = with config.flake.modules.nixos; [
      server
      edge
      crowdsec
      cache
    ];
    system.stateVersion = "26.05";
  };
}
