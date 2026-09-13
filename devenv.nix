{
  config,
  lib,
  pkgs,
  ...
}:
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
    pkgs.nixos-anywhere
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
    install = {
      exec = lib.replaceStrings [ "@coreutilsInstall@" ] [ "${pkgs.coreutils}/bin/install" ] (
        builtins.readFile ./scripts/devenv/install.sh
      );
      packages = [ pkgs.less ];
    };
    deploy.exec = builtins.readFile ./scripts/devenv/deploy.sh;
    tailnet.exec = builtins.readFile ./scripts/devenv/tailnet.sh;
    tailnet-sops.exec = builtins.readFile ./scripts/devenv/tailnet-sops.sh;
  };

  tasks = {
    "host:create" = {
      description = "Create an untracked/unready host scaffold; no evaluation, staging or installation.";
      exec = builtins.readFile ./scripts/devenv/host-create.sh;
      input = lib.genAttrs [ "name" "system" "track" "group" ] (_: null);
      showOutput = true;
    };
    "host:install" = {
      description = "Confirmed OS-only installation from a pinned live installer; full preflight, no kexec or reboot.";
      exec = builtins.readFile ./scripts/devenv/host-install.sh;
      input = lib.genAttrs [
        "host"
        "target"
        "port"
        "device"
        "identity"
        "fingerprint"
        "planHash"
        "confirm"
      ] (_: null);
      showOutput = true;
    };
    "deploy:run" = {
      description = "Confirmed host/group deployment with full preflight, remote builds and ordered rollback-protected activation.";
      exec = builtins.readFile ./scripts/devenv/deploy.sh;
      input = lib.genAttrs [ "target" "mode" "confirm" ] (_: null);
      showOutput = true;
    };
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
