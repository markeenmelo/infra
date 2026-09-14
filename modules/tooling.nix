{
  flake.modules.homeManager.desktop = { pkgs, ... }: { home.packages = [ pkgs.devenv ]; };

  perSystem =
    { pkgs, ... }:
    {
      formatter = pkgs.nixfmt-tree;
      packages.devenv = pkgs.devenv;
    };
}
