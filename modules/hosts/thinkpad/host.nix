{ config, ... }:
{
  fleet.hosts.thinkpad.tailnetAddress = "100.119.79.113";
  fleet.hosts.thinkpad.module = {
    imports = with config.flake.modules.nixos; [
      desktop
      remote-builds
      backup-home
    ];
    system.stateVersion = "26.11";
  };
}
