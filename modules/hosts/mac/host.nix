{ config, ... }:
{
  fleet.hosts.mac = {
    system = "aarch64-darwin";
    darwin = {
      imports = [ config.flake.modules.darwin.desktop ];
      system.stateVersion = 7;
      home-manager.users.marcos.home.stateVersion = "26.11";
    };
  };
}
