{
  flake.modules.homeManager.desktop = { pkgs, ... }: {
    home.packages = [
      pkgs.pavucontrol
      pkgs.networkmanagerapplet
    ];
    programs.btop.enable = true;
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
}
