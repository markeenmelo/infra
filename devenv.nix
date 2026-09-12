{
  config,
  pkgs,
  ...
}:
{
  # Native development entry point; production remains in flake.nix/modules/.
  # Do not resolve secrets in Nix, shell hooks, tasks or direnv's cached environment.
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
    # Same unstable package/provider as checks.x86_64-linux.tailscale-offline.
    package = pkgs.opentofu.withPlugins (providers: [ providers.tailscale_tailscale ]);
    lsp.package = pkgs.tofu-ls;
  };

  # Optional local hooks, not another canonical gate and never a live operation.
  # Opt in with `devenv --profile hooks shell`; ordinary shell entry installs none.
  profiles.hooks.module.git-hooks.hooks = {
    nixfmt.enable = true;
    statix.enable = true;
    deadnix.enable = true;
    shellcheck.enable = true;
    encrypted-secrets = {
      enable = true;
      name = "Encrypted payloads and public recipients (no decryption)";
      entry = "bash modules/secrets/check-secrets.sh";
      files = "^(secrets/|\\.sops\\.yaml$)";
      pass_filenames = false;
    };
  };

  tasks = {
    "repo:fmt".exec = ''
      set -euo pipefail
      cd "$DEVENV_ROOT"
      nix fmt --no-update-lock-file
      tofu -chdir=tofu/tailscale fmt -recursive
    '';
    "repo:format-check".exec = ''
      set -euo pipefail
      cd "$DEVENV_ROOT"
      treefmt --ci
      tofu -chdir=tofu/tailscale fmt -check -recursive
    '';
    "repo:lint".exec = ''
      set -euo pipefail
      cd "$DEVENV_ROOT"
      statix check .
      deadnix --fail .
      find modules -name '*.sh' -print0 | xargs -0 shellcheck .envrc
    '';
    "repo:secret-check".exec = ''
      cd "$DEVENV_ROOT"
      bash modules/secrets/check-secrets.sh
    '';
    "repo:secret-check-tests".exec = ''
      cd "$DEVENV_ROOT"
      bash modules/secrets/test-secret-check.sh
    '';
    "repo:tooling-check".exec = ''
      cd "$DEVENV_ROOT"
      python3 modules/tooling/check-devenv.py
    '';
    "repo:evaluate" = {
      # Serialize Nix evaluations to avoid competing for the same eval-cache DB.
      after = [
        "repo:secret-check"
        "repo:tooling-check"
      ];
      showOutput = true;
      exec = ''
        set -euo pipefail
        cd "$DEVENV_ROOT"
        nix eval --no-update-lock-file --json .#validation | jq '{hosts: (.hosts | map_values({track, revision, ready, missing, components})), fixtures, compositions, existingInstallations, sops, desktop, wifi, tailscale}'
      '';
    };
    "repo:check" = {
      description = "Canonical non-destructive gate; no credentials, target contact or activation";
      after = [
        "repo:format-check"
        "repo:lint"
        "repo:evaluate"
      ];
      showOutput = true;
      exec = ''
        set -euo pipefail
        cd "$DEVENV_ROOT"
        nix flake check --no-update-lock-file -L
      '';
    };
    "repo:inventory" = {
      showOutput = true;
      exec = ''
        set -euo pipefail
        cd "$DEVENV_ROOT"
        nix eval --no-update-lock-file --json .#fleet | jq .
      '';
    };
    "repo:tailscale-inventory" = {
      showOutput = true;
      exec = ''
        set -euo pipefail
        cd "$DEVENV_ROOT"
        nix eval --no-update-lock-file --json .#tailscalePlan | jq .
      '';
    };
    "repo:tailscale-check".exec = ''
      cd "$DEVENV_ROOT"
      bash modules/tailscale/check-tailscale.sh
    '';
    "repo:revisions" = {
      showOutput = true;
      exec = ''
        cd "$DEVENV_ROOT"
        jq '.nodes | with_entries(select(.value.locked)) | map_values(.locked | {rev, narHash, url})' flake.lock devenv.lock
      '';
    };
  };

  # Interactive/credential-bearing operations are scripts, NOT task graph nodes.
  # `devenv tasks run repo` must never include a deploy, plan, import or apply.
  scripts = {
    ready.exec = ''
      set -euo pipefail
      cd "$DEVENV_ROOT"
      exec bash modules/fleet/ready.sh "$@"
    '';
    build.exec = ''
      set -euo pipefail
      cd "$DEVENV_ROOT"
      [[ $# == 1 ]] || { echo 'Usage: build HOST' >&2; exit 1; }
      bash modules/fleet/ready.sh "$1"
      exec nix build --no-update-lock-file ".#nixosConfigurations.$1.config.system.build.toplevel"
    '';
    disk-plan.exec = ''
      set -euo pipefail
      cd "$DEVENV_ROOT"
      [[ $# == 1 ]] || { echo 'Usage: disk-plan HOST' >&2; exit 1; }
      bash modules/fleet/ready.sh "$1" disk-plan
      exec nix build --no-update-lock-file --out-link "result-disko-$1" ".#nixosConfigurations.$1.config.system.build.diskoScript"
    '';
    deploy.exec = ''
      set -euo pipefail
      cd "$DEVENV_ROOT"
      exec nix run --no-update-lock-file .#deploy-rs -- "$@"
    '';
    deploy-host.exec = ''
      set -euo pipefail
      cd "$DEVENV_ROOT"
      [[ $# == 1 ]] || { echo 'Usage: deploy-host HOST' >&2; exit 1; }
      devenv tasks run repo:check --mode before
      bash modules/fleet/ready.sh "$1" deploy
      exec deploy ".#$1" -- --no-update-lock-file
    '';
    deploy-fleet.exec = ''
      set -euo pipefail
      cd "$DEVENV_ROOT"
      [[ $# == 0 ]] || { echo 'Usage: deploy-fleet' >&2; exit 1; }
      devenv tasks run repo:check --mode before
      nix eval --no-update-lock-file --json .#deploy.nodes --apply builtins.attrNames | jq -e 'length > 0' > /dev/null
      exec deploy . -- --no-update-lock-file
    '';
    tailnet.exec = ''
      exec bash "$DEVENV_ROOT/modules/tailscale/tailscale-tofu.sh" "$@"
    '';
    tailnet-sops.exec = ''
      exec python3 "$DEVENV_ROOT/modules/tailscale/tailscale-sops.py" "$@"
    '';
  };

  enterTest = ''
    devenv tasks run repo:check --mode before
  '';

  assertions = [
    {
      # Module/CLI compatibility is exercised by the native task contract/tests,
      # not inferred from upstream's occasionally stale latest-version marker.
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
