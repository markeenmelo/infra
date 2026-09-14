{ config, ... }:
{
  fleet.hosts.racknerd = {
    system = "x86_64-linux";
    track = "stable";
    module.imports = with config.flake.modules.nixos; [
      server
      vps
    ];
  };
}
