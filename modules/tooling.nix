{ inputs, ... }:
{
  flake.modules.homeManager.desktop = { pkgs, ... }: { home.packages = [ pkgs.devenv ]; };

  perSystem =
    {
      pkgs,
      system,
      ...
    }:
    {
      config = {
        _module.args.pkgs = inputs.nixpkgs.legacyPackages.${system};
        formatter = pkgs.nixfmt-tree;
        packages.devenv = pkgs.devenv;
      };
    };
}
