{ config, ... }:
{
  fleet.hosts.mac = {
    system = "aarch64-darwin";
    tailnetAddress = "100.74.75.110";
    darwin = {
      imports = [ config.flake.modules.darwin.desktop ];
      system.stateVersion = 7;
      home-manager.users.marcos.home.stateVersion = "26.11";
    };
  };
}
