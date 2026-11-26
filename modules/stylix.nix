{ inputs, ... }:
let
  common =
    { pkgs, ... }:
    {
      stylix = {
        enable = true;
        base16Scheme = "${inputs.stylix.inputs.tinted-schemes}/base16/everforest.yaml";
        polarity = "dark";
        image = ./wallpaper.jpg;
        overlays.enable = false;
        fonts = {
          sizes = {
            terminal = 14;
            applications = 12;
            desktop = 12;
            popups = 12;
          };
          monospace = {
            package = pkgs.nerd-fonts.jetbrains-mono;
            name = "JetBrainsMono Nerd Font Mono";
          };
          sansSerif = {
            package = pkgs.nerd-fonts.noto;
            name = "NotoSans Nerd Font Propo";
          };
          serif = {
            package = pkgs.noto-fonts;
            name = "Noto Serif";
          };
        };
      };
    };
in
{
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
            zen-browser.profileNames = [ "default" ];
          };
        }
      ];
    };
}
