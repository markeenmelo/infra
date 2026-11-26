{ config, ... }:
{
  fleet.hosts.beast.tailnetAddress = "100.80.10.86";
  fleet.hosts.beast.telemetry = {
    metrics = null;
    logs = 3104;
  };
  fleet.hosts.beast.module = {
    imports = with config.flake.modules.nixos; [
      desktop
      gaming
      cache-client
      logs
      fwupd
    ];
    system.stateVersion = "26.11";
  };
}
