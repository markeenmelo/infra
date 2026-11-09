{ config, ... }:
{
  fleet.hosts.bastion.tailnetAddress = "100.105.158.109";
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
      backups
      builder
      proton-exit
    ];
    system.stateVersion = "26.05";
  };
}
