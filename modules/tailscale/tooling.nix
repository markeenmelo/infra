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
          shellcheck scripts/tailscale/reconcile.sh
          python3 scripts/tailscale/test-reconcile.py scripts/tailscale/reconcile.sh
          python3 scripts/tailscale/test-tofu-wrapper.py scripts/tailscale/tailscale-tofu.sh
          python3 scripts/tailscale/test-sops-wrapper.py scripts/tailscale/tailscale-sops.py
          bash scripts/tailscale/check-tailscale.sh
          touch "$out"
        '';
  };
}
