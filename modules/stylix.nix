{ inputs, ... }:
{
  flake.modules.darwin.desktop =
    { config, pkgs, ... }:
    {
      imports = [ inputs.stylix.darwinModules.stylix ];
      stylix = {
        enable = true;
        base16Scheme = "${inputs.stylix.inputs.tinted-schemes}/base16/onedark-dark.yaml";
        polarity = "dark";
        image = ./wallpaper.jpg;
        overlays.enable = false;
        fonts = {
          sizes = {
            terminal = 12;
            applications = 11;
            desktop = 11;
            popups = 11;
          };
          monospace = {
            package = pkgs.nerd-fonts.jetbrains-mono;
            name = "JetBrainsMono Nerd Font";
          };
          sansSerif = {
            package = pkgs.inter;
            name = "Inter";
          };
          serif = config.stylix.fonts.sansSerif;
        };
      };
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
}
