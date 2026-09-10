{ inputs, ... }:
{
  perSystem = { config, pkgs, ... }: {
    packages.tailscale-tofu = pkgs.opentofu.withPlugins (providers: [ providers.tailscale_tailscale ]);
    checks.tailscale-offline =
      pkgs.runCommand "tailscale-offline"
        {
          nativeBuildInputs = [
            config.packages.tailscale-tofu
            pkgs.python3
            pkgs.bash
            pkgs.jq
            pkgs.shellcheck
          ];
        }
        ''
          cd ${inputs.self}
          shellcheck modules/tailscale/reconcile.sh
          python3 modules/tailscale/test-reconcile.py modules/tailscale/reconcile.sh
          python3 modules/tailscale/test-tofu-wrapper.py scripts/tailscale-tofu.sh
          bash scripts/check-tailscale.sh
          touch "$out"
        '';
  };
}
