{
  flake.modules.nixos.desktop.programs.kdeconnect.enable = true;
  flake.modules.homeManager.desktop = { pkgs, ... }: {
    services.kdeconnect.enable = true;
    xdg.autostart = {
      enable = true;
      entries = [
        "${
          pkgs.makeDesktopItem {
            name = "org.kde.kdeconnect.daemon";
            desktopName = "Disabled duplicate org.kde.kdeconnect.daemon autostart";
            exec = "${pkgs.coreutils}/bin/false";
            noDisplay = true;
            extraConfig.Hidden = "true";
          }
        }/share/applications/org.kde.kdeconnect.daemon.desktop"
      ];
    };
  };
}
