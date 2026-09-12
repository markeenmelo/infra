{ inputs, ... }:
{
  perSystem =
    {
      lib,
      pkgs,
      system,
      ...
    }:
    {
      config = {
        # Unstable development/check tools; host packages use their own explicit track.
        _module.args.pkgs = inputs.nixpkgs.legacyPackages.${system};
        formatter = pkgs.nixfmt-tree;
        # Bootstrap without installing anything or retaining a parallel devShell.
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
              ];
            }
            ''
              cd ${inputs.self}
              if find . -name '*.nix' ! -path './flake.nix' ! -path './devenv.nix' ! -path './modules/*' -print -quit | grep -q .; then
                echo 'Only flake.nix and devenv.nix are entry points; other Nix files must be top-level modules under modules/.' >&2
                exit 1
              fi
              find . -name '*.nix' -print0 | xargs -0 -n1 nixfmt --check
              statix check .
              deadnix --fail .
              find modules -name '*.sh' -print0 | xargs -0 shellcheck .envrc
              touch "$out"
            '';
      };
    };
}
