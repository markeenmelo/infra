{ config, ... }:
{
  fleet.hosts.bastion.module = {
    imports = with config.flake.modules.nixos; [
      server
      lan-proxy
      authelia
      immich
      frigate
      opencloud
      jellyfin
      arr
    ];
    system.stateVersion = "26.05";
  };
}
