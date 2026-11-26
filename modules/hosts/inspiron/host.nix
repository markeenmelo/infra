{ config, ... }:
{
  fleet.hosts.inspiron = {
    tailnetAddress = "100.114.47.76";
    telemetry = {
      metrics = 9098;
      logs = 3106;
      alwaysOn = false;
    };
    module = {
      imports = with config.flake.modules.nixos; [
        plain-storage
        kiosk
        cache-client
        secure-boot
        telemetry
      ];
      system.stateVersion = "26.11";
    };
  };
}
