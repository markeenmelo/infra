{ inputs, ... }:
let
  common =
    { config, pkgs, ... }:
    {
      stylix = {
        enable = true;
        base16Scheme = "${inputs.stylix.inputs.tinted-schemes}/base16/onedark-dark.yaml";
        polarity = "dark";
        image = ./wallpaper.jpg;
        overlays.enable = false;
        opacity = {
          desktop = 0.9;
          popups = 0.9;
        };
        fonts = {
          sizes = {
            terminal = 12;
            applications = 11;
            desktop = 11;
            popups = 11;
          };
          monospace = {
            package = pkgs.nerd-fonts.jetbrains-mono;
            name = "JetBrainsMono Nerd Font Mono";
          };
          sansSerif = {
            package = pkgs.nerd-fonts.noto;
            name = "NotoSans Nerd Font Propo";
          };
          serif = config.stylix.fonts.sansSerif;
        };
      };
    };
in
{
  flake.modules.darwin.desktop =
    { config, pkgs, ... }:
    {
      imports = [
        inputs.stylix.darwinModules.stylix
        common
      ];
      fonts.packages = config.stylix.fonts.packages;
      home-manager.users.${config.system.primaryUser} =
        { lib, ... }:
        {
          stylix.targets.rofi.enable = false;
          home.activation.wallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            run ${lib.getExe pkgs.desktoppr} ${config.stylix.image} || echo "warning: could not set the wallpaper" >&2
          '';
        };
    };

  flake.modules.nixos.desktop =
    { pkgs, ... }:
    {
      imports = [
        inputs.stylix.nixosModules.stylix
        common
      ];
      stylix = {
        targets.plymouth.logoAnimated = false;
        cursor = {
          package = pkgs.bibata-cursors;
          name = "Bibata-Modern-Classic";
          size = 24;
        };
        icons = {
          enable = true;
          package = pkgs.papirus-icon-theme;
          dark = "Papirus-Dark";
          light = "Papirus";
        };
      };
      home-manager.sharedModules = [
        {
          stylix.targets = {
            rofi.enable = false;
            zen-browser.profileNames = [ "default" ];
          };
        }
      ];
    };
}
