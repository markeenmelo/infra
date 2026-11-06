{ config, ... }:
{
  fleet.hosts.bastion.module = {
    imports = with config.flake.modules.nixos; [
      server
      lan-proxy
      authelia
      immich
    ];
    system.stateVersion = "26.05";
  };
}
