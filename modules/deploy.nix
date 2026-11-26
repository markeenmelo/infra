{
  config,
  lib,
  inputs,
  ...
}:
let
  inherit (config.fleet) hosts;
  systems = lib.unique (lib.mapAttrsToList (_: host: host.system) hosts);
  clean = "/run/current-system/sw/bin/clean-generations";
  nodes = config.flake.deploy.nodes;
  deployLib =
    system:
    (inputs.nixpkgs.legacyPackages.${system}.appendOverlays [
      inputs.deploy-rs.overlays.default
      (_: prev: {
        deploy-rs = {
          inherit (inputs.nixpkgs.legacyPackages.${system}) deploy-rs;
          inherit (prev.deploy-rs) lib;
        };
      })
    ]).deploy-rs.lib;
in
{
  flake = {
    deploy.nodes = lib.mapAttrs (name: host: {
      hostname = name;
      sshUser = "deploy";
      remoteBuild = config.flake.nixosConfigurations.${name}.config.nix.settings.max-jobs != 0;
      groups = [ (if host.alwaysOn then "servers" else "workstations") ];
      profiles.system = {
        user = "root";
        path = (deployLib host.system).activate.nixos config.flake.nixosConfigurations.${name};
      };
    }) hosts;

    checks = lib.genAttrs systems (
      system:
      (deployLib system).deployChecks {
        nodes = lib.filterAttrs (
          name: _: config.fleet.hosts.${name}.system == system
        ) config.flake.deploy.nodes;
      }
    );

    modules.nixos.base =
      { config, pkgs, ... }:
      {
        environment.systemPackages = [
          (pkgs.writeShellApplication {
            name = "clean-generations";
            runtimeInputs = [ config.nix.package ];
            text =
              if config.programs.nh.enable then
                "exec ${lib.getExe config.programs.nh.package} clean all --keep 2 --optimise"
              else
                ''
                  nix-env --profile /nix/var/nix/profiles/system --delete-generations +2
                  nix-collect-garbage
                  nix-store --optimise
                '';
          })
        ];
        users = {
          users.deploy = {
            isSystemUser = true;
            group = "deploy";
            useDefaultShell = true;
            openssh.authorizedKeys.keys = [
              "restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGT8qIye6ycv8MsJFQuX05FGRhyhouGszp2SW7Qmbz0D"
            ];
          };
          groups.deploy = { };
        };
        system.activationScripts.diff = lib.mkIf (!config.programs.nh.enable) {
          supportsDryActivation = true;
          text = ''
            [ -e /run/current-system ] && ${lib.getExe pkgs.dix} diff /run/current-system "$systemConfig" || true
          '';
        };
        services.openssh.settings.AllowUsers = [ "deploy" ];
        nix.settings.trusted-users = [ "deploy" ];
        security.sudo.extraRules = [
          {
            users = [ "deploy" ];
            runAs = "root";
            commands = [
              {
                command = "/nix/store/*/activate-rs *";
                options = [ "NOPASSWD" ];
              }
              {
                command = "/run/current-system/sw/bin/rm ^/tmp/deploy-rs-canary-[a-z0-9]{32}$";
                options = [ "NOPASSWD" ];
              }
              {
                command = "/run/current-system/sw/bin/systemctl reboot";
                options = [ "NOPASSWD" ];
              }
              {
                command = "/run/current-system/sw/bin/systemctl poweroff";
                options = [ "NOPASSWD" ];
              }
              {
                command = ''${clean} ""'';
                options = [ "NOPASSWD" ];
              }
            ];
          }
        ];
      };
  };

  perSystem =
    {
      lib,
      pkgs,
      ...
    }:
    let
      hostCases = lib.concatMapStrings (name: "  ${name}) ;;\n") (lib.attrNames hosts);
      deployCases = lib.concatMapStrings (name: "  ${name}) exec \"$deploy\" \".#${name}\" \"$@\" ;;\n") (
        lib.attrNames hosts
      );
      members = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          name: host: "${name} ${host.tailnetAddress} ${toString nodes.${name}.groups}"
        ) hosts
      );
      systemctl = name: verb: description: {
        meta = { inherit description; };
        program = pkgs.writeShellApplication {
          inherit name;
          runtimeInputs = [ pkgs.openssh ];
          text = ''
            case ''${1-} in
            ${hostCases}  *) echo "${name}: no NixOS host named ''${1-}" >&2; exit 1 ;;
            esac
            ssh "deploy@$1" sudo /run/current-system/sw/bin/systemctl ${verb}
          '';
        };
      };
    in
    {
      apps.deploy = {
        meta.description = "deploy TARGET [--boot]: activate the committed configuration with magic rollback on a host, or on the online hosts of a deploy group (servers, workstations or all), over the tailnet; --boot sets the boot default only and has no rollback";
        program = pkgs.writeShellApplication {
          name = "deploy";
          runtimeInputs = [
            pkgs.git
            pkgs.jq
          ];
          text = ''
            target=''${1-}
            shift || true
            for arg in "$@"; do
              case $arg in
                --boot | --dry-activate | --remote-build | --debug-logs | -d) ;;
                *) echo "deploy: $arg is not allowed" >&2; exit 1 ;;
              esac
            done
            git diff --quiet HEAD || { echo "deploy: commit the tracked changes first" >&2; exit 1; }
            deploy=${lib.getExe pkgs.deploy-rs}
            case $target in
            ${deployCases}  servers | workstations | all) ;;
              *) echo "deploy: name a host or a group (servers, workstations, all), not '$target'" >&2; exit 1 ;;
            esac
            online=$(tailscale status --json | jq -r '[.Self] + [.Peer[]?] | .[] | select(.Online) | .TailscaleIPs[]?')
            targets=()
            while read -r host address groups; do
              [ "$target" = all ] || [[ " $groups " == *" $target "* ]] || continue
              if grep -qxF "$address" <<< "$online"; then
                targets+=(".#$host")
              else
                echo "deploy: skipping $host, offline" >&2
              fi
            done <<< ${lib.escapeShellArg members}
            [ ''${#targets[@]} -gt 0 ] || { echo "deploy: no host in $target is online" >&2; exit 1; }
            groups=()
            [ "$target" = all ] || groups=(--groups "$target")
            exec "$deploy" --targets "''${targets[@]}" "''${groups[@]}" "$@"
          '';
        };
      };
      apps.reboot =
        systemctl "reboot" "reboot"
          "reboot HOST: reboot a NixOS host over the tailnet as the deploy account, e.g. after deploy --boot";
      apps.shutdown =
        systemctl "shutdown" "poweroff"
          "shutdown HOST: power off a NixOS host over the tailnet as the deploy account, at once and without asking; wake brings bastion back only from home and edge through the Oracle Cloud API, where it waits for its disk passphrase";
      apps.clean = {
        meta.description = "clean [HOST]: delete every generation but the newest two and optimise the store on HOST over the tailnet as the deploy account, or on this machine without HOST";
        program = pkgs.writeShellApplication {
          name = "clean";
          runtimeInputs = [ pkgs.openssh ];
          text = ''
            [ $# -eq 0 ] && exec ${lib.getExe pkgs.nh} clean all --keep 2 --optimise
            case $1 in
            ${hostCases}  *) echo "clean: no NixOS host named $1" >&2; exit 1 ;;
            esac
            ssh "deploy@$1" sudo ${clean}
          '';
        };
      };
    };
}
