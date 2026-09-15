{
  flake.modules.nixos.desktop.programs.kdeconnect.enable = true;
  flake.modules.homeManager.desktop = {
    services.kdeconnect.enable = true;
    xdg.configFile."autostart/org.kde.kdeconnect.daemon.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=org.kde.kdeconnect.daemon
      Hidden=true
    '';
  };
}
