{ config, ... }:
{
  fleet.hosts.bastion.module = {
    imports = with config.flake.modules.nixos; [
      server
      lan-proxy
    ];
    system.stateVersion = "26.05";
  };
}
