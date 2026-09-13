{
  perSystem = { pkgs, ... }: {
    packages.tailscale-tofu = pkgs.opentofu.withPlugins (providers: [ providers.tailscale_tailscale ]);
  };
}
