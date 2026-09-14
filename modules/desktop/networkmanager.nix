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

  flake.modules.homeManager.desktop = { pkgs, ... }: {
    home.packages = [ pkgs.networkmanagerapplet ];
    xdg.autostart = {
      enable = true;
      entries = [
        "${
          pkgs.makeDesktopItem {
            name = "nm-applet";
            desktopName = "Disabled duplicate nm-applet autostart";
            exec = "${pkgs.coreutils}/bin/false";
            noDisplay = true;
            extraConfig.Hidden = "true";
          }
        }/share/applications/nm-applet.desktop"
      ];
    };
  };

  fleet.hosts.thinkpad.module.networking.networkmanager.wifi.powersave = true;
}
