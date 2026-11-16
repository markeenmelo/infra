{
  perSystem =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      formatter = pkgs.nixfmt-tree;
      devShells.default = pkgs.mkShellNoCC {
        packages = [
          config.formatter
          pkgs.just
          pkgs.sops
        ];
      };
      checks = {
        dev-shell = config.devShells.default;
        apps = pkgs.runCommand "apps" {
          programs = lib.mapAttrsToList (_: app: app.program) config.apps;
        } "touch $out";
        format =
          pkgs.runCommand "format"
            {
              nativeBuildInputs = [
                config.formatter
                pkgs.just
              ];
            }
            ''
              cd ${../.}
              treefmt --ci --tree-root .
              just --fmt --check
              touch $out
            '';
      };
    };
}
