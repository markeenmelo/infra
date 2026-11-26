{ config, ... }:
{
  fleet.hosts.thinkpad.tailnetAddress = "100.119.79.113";
  fleet.hosts.thinkpad.alwaysOn = false;
  fleet.hosts.thinkpad.telemetry = {
    metrics = 9099;
    logs = 3103;
  };
  fleet.hosts.thinkpad.module = {
    imports = with config.flake.modules.nixos; [
      storage
      desktop
      wifi
      remote-builds
      gaming
      telemetry
      fwupd
      secure-boot
    ];
    system.stateVersion = "26.11";
  };
}
