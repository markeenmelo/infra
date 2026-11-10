{ config, ... }:
{
  fleet.hosts.asahi = {
    system = "aarch64-linux";
    tailnetAddress = "100.122.51.97";
    module = {
      imports = with config.flake.modules.nixos; [
        desktop
        remote-builds
      ];
      system.stateVersion = "26.11";
    };
  };
}
