{ inputs, ... }:
{
  perSystem =
    {
      config,
      lib,
      pkgs,
      system,
      ...
    }:
    {
      options.devPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "Feature-owned packages for the locked development shell, using this per-system evaluation only.";
      };
      config = {
        # Developer tools are deliberately stable and independent of every host's pkgs.
        _module.args.pkgs = inputs.nixpkgs-stable.legacyPackages.${system};
        formatter = pkgs.nixfmt-tree;
        devShells.default = pkgs.mkShellNoCC { packages = config.devPackages; };
        devPackages = [
          pkgs.nixfmt-tree
          pkgs.nixfmt
          pkgs.statix
          pkgs.deadnix
          pkgs.just
          pkgs.jq
          pkgs.git
          pkgs.openssh
          pkgs.shellcheck
          pkgs.python3
        ];
        checks.source-quality =
          pkgs.runCommand "source-quality"
            {
              nativeBuildInputs = [
                pkgs.nixfmt
                pkgs.statix
                pkgs.deadnix
                pkgs.shellcheck
              ];
            }
            ''
              cd ${inputs.self}
              if find . -name '*.nix' ! -path './flake.nix' ! -path './modules/*' -print -quit | grep -q .; then
                echo 'Every non-entry Nix file must be a top-level module under modules/.' >&2
                exit 1
              fi
              find . -name '*.nix' -print0 | xargs -0 -n1 nixfmt --check
              statix check .
              deadnix --fail .
              find modules -name '*.sh' -print0 | xargs -0 shellcheck
              touch "$out"
            '';
      };
    };
}
