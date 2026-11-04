{
  perSystem =
    { config, pkgs, ... }:
    {
      formatter = pkgs.nixfmt-tree;
      devShells.default = pkgs.mkShellNoCC { packages = [ config.formatter ]; };
      checks.dev-shell = config.devShells.default;
    };
}
