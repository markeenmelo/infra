{
  config,
  pkgs,
  ...
}:
let
  nixosAnywhere = pkgs.nixos-anywhere.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/nixos-anywhere.sh \
        --replace-fail ' "-o" "UserKnownHostsFile=/dev/null" "-o" "StrictHostKeyChecking=no"' "" \
        --replace-fail '-o IdentitiesOnly=no' '-o IdentitiesOnly=yes' \
        --replace-fail '    --ssh-option)' $'    --ssh-config)\n      sshArgs+=("-F" "$2")\n      shift\n      ;;\n    --ssh-option)' \
        --replace-fail '* --ssh-option <ssh_option>' $'* --ssh-config <config_file>\n  use a private SSH configuration instead of user/system SSH configuration.\n* --ssh-option <ssh_option>'
    '';
  });
in
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
    nixosAnywhere
    pkgs.shellcheck
    pkgs.bash-language-server
    pkgs.python3
    pkgs.sops
    pkgs.age
    pkgs.yq-go
    pkgs.opentofu
  ];

  tasks = {
    "tailnet:deploy" = {
      description = "Plan tailnet changes or apply one explicitly authorized saved plan; no host operations.";
      cwd = config.devenv.root;
      showOutput = true;
      exec = "exec ${pkgs.bash}/bin/bash scripts/devenv/tailnet.sh";
    };
    "fleet:install" = {
      description = "Install one reviewed host (destructive); prepare=true prepares private files, with optional explicit authorizeKey=true live-installer key upload.";
      cwd = config.devenv.root;
      showOutput = true;
      exec = "exec ${pkgs.bash}/bin/bash scripts/devenv/install.sh";
    };
    "fleet:deploy" = {
      description = "Deploy a server or the servers group; boot=true stages then requests reboot.";
      cwd = config.devenv.root;
      showOutput = true;
      exec = "exec ${pkgs.bash}/bin/bash scripts/devenv/deploy.sh";
    };
  };

  assertions = [
    {
      assertion = config.devenv.cli.version == pkgs.devenv.version;
      message = "Use the locked CLI: nix run --no-update-lock-file .#devenv -- shell.";
    }
    {
      assertion = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
      message = "This fleet's development environment supports x86_64-linux only.";
    }
    {
      assertion = !config.secretspec.enable;
      message = "Never load operator secrets through secretspec; decrypt them only in an explicit operator process.";
    }
  ];
}
