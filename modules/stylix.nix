{ inputs, ... }:
{
  flake.modules.darwin.desktop =
    { config, pkgs, ... }:
    {
      imports = [ inputs.stylix.darwinModules.stylix ];
      stylix = {
        enable = true;
        base16Scheme = "${pkgs.base16-schemes}/share/themes/onedark-dark.yaml";
        polarity = "dark";
        overlays.enable = false;
        fonts = {
          sizes = {
            terminal = 12;
            applications = 11;
          };
          monospace = {
            package = pkgs.nerd-fonts.jetbrains-mono;
            name = "JetBrainsMono Nerd Font";
          };
          sansSerif = {
            package = pkgs.inter;
            name = "Inter";
          };
        };
      };
      fonts.packages = config.stylix.fonts.packages;
    };
}
