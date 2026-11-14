{ config, ... }:
{
  fleet.hosts.thinkpad.tailnetAddress = "100.119.79.113";
  fleet.hosts.thinkpad.telemetry = {
    metrics = null;
    logs = 3103;
  };
  fleet.hosts.thinkpad.module = {
    imports = with config.flake.modules.nixos; [
      desktop
      remote-builds
      backup-home
      gaming
      logs
    ];
    system.stateVersion = "26.11";
  };
}
