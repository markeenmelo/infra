{
  flake.modules.nixos.desktop.services = {
    gvfs.enable = true;
    udisks2.enable = true;
  };
  flake.modules.homeManager.desktop = { pkgs, ... }: {
    home.packages = [
      pkgs.nautilus
      pkgs.file-roller
      pkgs.papers
      pkgs.loupe
    ];
    xdg = {
      mimeApps = {
        enable = true;
        defaultApplications = {
          "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
          "application/pdf" = [ "org.gnome.Papers.desktop" ];
          "application/zip" = [ "org.gnome.FileRoller.desktop" ];
          "application/x-7z-compressed" = [ "org.gnome.FileRoller.desktop" ];
          "application/x-tar" = [ "org.gnome.FileRoller.desktop" ];
          "image/jpeg" = [ "org.gnome.Loupe.desktop" ];
          "image/png" = [ "org.gnome.Loupe.desktop" ];
          "image/webp" = [ "org.gnome.Loupe.desktop" ];
        };
      };
    };
  };
}
