{ config, ... }:
{
  fleet.hosts.thinkpad = {
    system = "x86_64-linux";
    track = "unstable";
    module.imports = with config.flake.modules.nixos; [
      desktop
      laptop
    ];
  };
}
