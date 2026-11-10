{
  perSystem =
    { config, pkgs, ... }:
    {
      formatter = pkgs.nixfmt-tree;
      devShells.default = pkgs.mkShellNoCC {
        packages = [
          config.formatter
          pkgs.just
          pkgs.sops
        ];
      };
      checks.dev-shell = config.devShells.default;
    };
}
