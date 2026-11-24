{ inputs, ... }:
let
  common =
    { pkgs, ... }:
    {
      stylix = {
        enable = true;
        base16Scheme = "${inputs.stylix.inputs.tinted-schemes}/base16/tokyo-night-terminal-dark.yaml";
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
