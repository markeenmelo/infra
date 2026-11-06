{ config, ... }:
{
  fleet.hosts.bastion.module = {
    imports = with config.flake.modules.nixos; [
      server
      lan-proxy
      authelia
      immich
      frigate
    ];
    system.stateVersion = "26.05";
  };
}
