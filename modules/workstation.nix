{
  flake.modules.nixos.desktop =
    { config, lib, ... }:
    {
      networking.networkmanager.enable = true;
      users.users = lib.optionalAttrs (config.fleet.access.admin != null) {
        ${config.fleet.access.admin}.extraGroups = [ "networkmanager" ];
      };
      environment.persistence."/persist".directories = [
        {
          directory = "/etc/NetworkManager/system-connections";
          mode = "0700";
        }
        "/var/lib/NetworkManager"
      ];
    };
}
