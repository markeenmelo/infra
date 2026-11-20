{ config, ... }:
{
  fleet.hosts.thinkpad.tailnetAddress = "100.119.79.113";
  fleet.hosts.thinkpad.telemetry = {
    metrics = null;
    logs = 3103;
  };
  # the uid that owns the ThinkPad's repository, allocated by the old generation
  fleet.hosts.thinkpad.homeBackup = {
    port = 8010;
    uid = 355;
  };
  fleet.hosts.thinkpad.module = {
    imports = with config.flake.modules.nixos; [
      desktop
      remote-builds
      backup-home
      logs
    ];
    system.stateVersion = "26.11";
  };
}
