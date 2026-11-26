{ config, ... }:
{
  fleet.hosts.beast.tailnetAddress = "100.80.10.86";
  fleet.hosts.beast.telemetry = {
    metrics = 9095;
    alwaysOn = false;
    logs = 3104;
  };
  fleet.hosts.beast.module = {
    imports = with config.flake.modules.nixos; [
      storage
      desktop
      gaming
      cache-client
      telemetry
      fwupd
      secure-boot
    ];
    gaming.restProfile = "power-saver";
    system.stateVersion = "26.11";
  };
}
