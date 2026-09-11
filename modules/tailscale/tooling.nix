{ inputs, ... }:
{
  perSystem = { config, pkgs, ... }: {
    devPackages = [ config.packages.tailscale-tofu ];
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
          python3 modules/tailscale/test-tofu-wrapper.py modules/tailscale/tailscale-tofu.sh
          bash modules/tailscale/check-tailscale.sh
          touch "$out"
        '';
  };
}
