{ config, ... }:
{
  fleet.hosts.bastion = {
    system = "x86_64-linux";
    track = "stable";
    module.imports = [ config.flake.modules.nixos.server ];
  };
}
