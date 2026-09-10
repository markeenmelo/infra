{ inputs, ... }:
{
  perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    {
      # Developer tools are deliberately stable and independent of every host's pkgs.
      _module.args.pkgs = inputs.nixpkgs-stable.legacyPackages.${system};
      formatter = pkgs.nixfmt-tree;
      devShells.default = pkgs.mkShellNoCC {
        packages = [
          pkgs.nixfmt-tree
          pkgs.nixfmt
          pkgs.statix
          pkgs.deadnix
          pkgs.just
          pkgs.jq
          pkgs.sops
          pkgs.age
          pkgs.yq-go
          pkgs.git
          pkgs.openssh
          pkgs.shellcheck
          config.packages.deploy-rs
          config.packages.tailscale-tofu
          pkgs.python3
        ];
      };
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
            find . -name '*.nix' -print0 | xargs -0 -n1 nixfmt --check
            statix check .
            deadnix --fail .
            shellcheck scripts/*.sh
            touch "$out"
          '';
    };
}
