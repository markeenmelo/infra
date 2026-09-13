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
    ready.exec = ''
      set -euo pipefail
      cd "$DEVENV_ROOT"
      exec bash scripts/fleet/ready.sh "$@"
    '';
    build.exec = ''
      set -euo pipefail
      cd "$DEVENV_ROOT"
      [[ $# == 1 ]] || { echo 'Usage: build HOST' >&2; exit 1; }
      bash scripts/fleet/ready.sh "$1"
      exec nix build --no-update-lock-file ".#nixosConfigurations.$1.config.system.build.toplevel"
    '';
    disk-plan.exec = ''
      set -euo pipefail
      cd "$DEVENV_ROOT"
      [[ $# == 1 ]] || { echo 'Usage: disk-plan HOST' >&2; exit 1; }
      bash scripts/fleet/ready.sh "$1" disk-plan
      exec nix build --no-update-lock-file --out-link "result-disko-$1" ".#nixosConfigurations.$1.config.system.build.diskoScript"
    '';
    deploy.exec = ''
      set -euo pipefail
      cd "$DEVENV_ROOT"
      exec nix run --no-update-lock-file .#deploy-rs -- "$@"
    '';
    tailnet.exec = ''
      exec bash "$DEVENV_ROOT/scripts/tailscale/tailscale-tofu.sh" "$@"
    '';
    tailnet-sops.exec = ''
      exec python3 "$DEVENV_ROOT/scripts/tailscale/tailscale-sops.py" "$@"
    '';
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
