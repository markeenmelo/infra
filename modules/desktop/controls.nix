{
  flake.modules.homeManager.desktop = { pkgs, ... }: {
    home.packages = [ pkgs.pavucontrol ];
    programs.btop.enable = true;
  };
}
