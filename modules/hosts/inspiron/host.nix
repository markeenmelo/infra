{ config, ... }:
{
  fleet.hosts.inspiron = {
    tailnetAddress = "100.114.47.76";
    module = {
      imports = with config.flake.modules.nixos; [
        plain-storage
        kiosk
        cache-client
        secure-boot
      ];
      system.stateVersion = "26.11";
    };
  };
}
