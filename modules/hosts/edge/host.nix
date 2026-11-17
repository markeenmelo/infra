{ config, ... }:
{
  fleet.hosts.edge = {
    system = "aarch64-linux";
    tailnetAddress = "100.78.192.61";
    publicAddress = "40.233.65.50";
    telemetry = {
      metrics = 9097;
      logs = 3105;
    };
    unlock = {
      port = 22022;
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKrNoF3lppFQJ7UcGh0MGmmboXvaj4bb6EHl+G5ku0he";
    };
    module = {
      imports = with config.flake.modules.nixos; [
        server
        telemetry
        unlock
      ];
      system.stateVersion = "26.11";
    };
  };
}
