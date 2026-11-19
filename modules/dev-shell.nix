{
  perSystem =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      formatter = pkgs.nixfmt-tree.override {
        runtimeInputs = [
          pkgs.opentofu
          pkgs.prettier
          pkgs.shfmt
          pkgs.stylua
          pkgs.taplo
        ];
        settings = {
          excludes = [
            "secrets/*"
            "modules/sketchybar.lua"
          ];
          formatter = {
            tofu = {
              command = "tofu";
              options = [ "fmt" ];
              includes = [ "*.tf" ];
            };
            stylua = {
              command = "stylua";
              includes = [
                "*.lua"
                "*.luau"
              ];
            };
            shfmt = {
              command = "shfmt";
              options = [
                "-w"
                "-i=2"
                "-sr"
              ];
              includes = [ "*.sh" ];
            };
            taplo = {
              command = "taplo";
              options = [ "format" ];
              includes = [ "*.toml" ];
            };
            prettier = {
              command = "prettier";
              options = [ "--write" ];
              includes = [
                "*.json"
                "*.yaml"
                "*.yml"
              ];
            };
          };
        };
      };
      devShells.default = pkgs.mkShellNoCC {
        packages = [
          config.formatter
          pkgs.jq
          pkgs.just
          pkgs.mkpasswd
          pkgs.openssl
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
