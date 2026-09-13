{ inputs, ... }:
{
  flake.modules.homeManager.desktop = { pkgs, ... }: { home.packages = [ pkgs.devenv ]; };

  perSystem =
    {
      lib,
      pkgs,
      system,
      ...
    }:
    {
      config = {
        _module.args.pkgs = inputs.nixpkgs.legacyPackages.${system};
        formatter = pkgs.nixfmt-tree;
        packages.devenv = pkgs.devenv;
        checks.source-quality =
          assert lib.assertMsg
            (
              (lib.importJSON ../devenv.lock).nodes.nixpkgs.locked == (lib.importJSON ../flake.lock)
              .nodes.nixpkgs.locked
            )
            "devenv.lock must use the flake's locked unstable tooling source; synchronize it after a nixpkgs update.";
          pkgs.runCommand "source-quality"
            {
              nativeBuildInputs = [
                pkgs.nixfmt
                pkgs.statix
                pkgs.deadnix
                pkgs.shellcheck
                pkgs.python3
              ];
            }
            ''
              cd ${inputs.self}
              if find . -name '*.nix' ! -path './flake.nix' ! -path './devenv.nix' ! -path './modules/*' -print -quit | grep -q .; then
                echo 'Only flake.nix and devenv.nix are entry points; other Nix files must be top-level modules under modules/.' >&2
                exit 1
              fi
              if find modules -type f ! -name '*.nix' -print -quit | grep -q .; then
                echo 'modules/ contains only Nix modules; executables belong in scripts/ and static data in assets/.' >&2
                exit 1
              fi
              find . -name '*.nix' -print0 | xargs -0 -n1 nixfmt --check
              statix check .
              deadnix --fail .
              find scripts -name '*.sh' -print0 | xargs -0 shellcheck .envrc
              python3 scripts/agents/check-guidance.py "$PWD"
              touch "$out"
            '';
      };
    };
}
