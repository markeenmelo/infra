{ config, pkgs, ... }:
{
  stdenv = pkgs.stdenvNoCC;
  cachix.enable = false;
  dotenv.enable = false;
  devenv.warnOnNewVersion = false;

  packages = [
    pkgs.devenv
    pkgs.nix
    pkgs.nixfmt-tree
    pkgs.nixfmt
    pkgs.statix
    pkgs.deadnix
    pkgs.nixd
    pkgs.jq
    pkgs.git
    pkgs.openssh
    pkgs.shellcheck
    pkgs.bash-language-server
    pkgs.python3
    pkgs.sops
    pkgs.age
    pkgs.yq-go
  ];

  languages.opentofu = {
    enable = true;
    package = pkgs.opentofu.withPlugins (providers: [ providers.tailscale_tailscale ]);
    lsp.package = pkgs.tofu-ls;
  };

  scripts = {
    ready.exec = builtins.readFile ./scripts/devenv/ready.sh;
    build.exec = builtins.readFile ./scripts/devenv/build.sh;
    disk-plan.exec = builtins.readFile ./scripts/devenv/disk-plan.sh;
    deploy.exec = builtins.readFile ./scripts/devenv/deploy.sh;
    tailnet.exec = builtins.readFile ./scripts/devenv/tailnet.sh;
    tailnet-sops.exec = builtins.readFile ./scripts/devenv/tailnet-sops.sh;
  };

  assertions = [
    {
      assertion = config.devenv.cli.version == pkgs.devenv.version;
      message = "Use the locked CLI: nix run --no-update-lock-file .#devenv -- shell.";
    }
    {
      assertion = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
      message = "This fleet's development environment and provider lock support x86_64-linux only.";
    }
    {
      assertion = !config.secretspec.enable && !config.dotenv.enable;
      message = "Load operator secrets only in the explicit tailnet-sops process, never into Nix or the development shell.";
    }
  ];
}
