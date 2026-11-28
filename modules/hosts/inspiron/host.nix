{ config, ... }:
{
  fleet.hosts.inspiron = {
    tailnetAddress = "100.114.47.76";
    alwaysOn = false;
    telemetry = {
      metrics = 9098;
      logs = 3106;
    };
    module = {
      imports = with config.flake.modules.nixos; [
        plain-storage
        kiosk
        cache-client
        secure-boot
        fwupd
        telemetry
      ];
      system = {
        stateVersion = "26.11";
        etc.overlay.enable = true;
      };
      services.userborn = {
        enable = true;
        passwordFilesLocation = "/var/lib/nixos";
      };
    };
  };
}
