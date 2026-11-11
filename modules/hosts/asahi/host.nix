{ config, ... }:
{
  fleet.hosts.asahi = {
    system = "aarch64-linux";
    tailnetAddress = "100.122.51.97";
    telemetry = {
      metrics = null;
      logs = 3104;
    };
    module = {
      imports = with config.flake.modules.nixos; [
        desktop
        remote-builds
        logs
      ];
      system.stateVersion = "26.11";
    };
  };
}
