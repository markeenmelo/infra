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
      config,
      lib,
      pkgs,
      ...
    }:
    let
      hostCases = lib.concatMapStrings (name: "  ${name}) ;;\n") (lib.attrNames hosts);
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
        meta.description = "deploy .#HOST: activate the host's committed configuration over the tailnet with magic rollback; --boot sets the boot default only and has no rollback";
        program = pkgs.writeShellApplication {
          name = "deploy";
          runtimeInputs = [ pkgs.git ];
          text = ''
            refuse() {
              echo "deploy: $1 is not allowed" >&2
              exit 1
            }
            targets=0
            for arg in "$@"; do
              case $arg in
                .#*) targets=1 ;;
                --targets | --boot | --dry-activate | --remote-build | --debug-logs | -d) ;;
                *) refuse "$arg" ;;
              esac
            done
            [ "$targets" -eq 1 ] || { echo "deploy: name a target, e.g. .#HOST" >&2; exit 1; }
            git diff --quiet HEAD || { echo "deploy: commit the tracked changes first" >&2; exit 1; }
            exec ${lib.getExe pkgs.deploy-rs} "$@"
          '';
        };
      };
      apps.deploy-online = {
        meta.description = "deploy-online [--boot]: deploy every NixOS host the tailnet shows online in one run of the deploy app, naming each one skipped";
        program = pkgs.writeShellApplication {
          name = "deploy-online";
          runtimeInputs = [ pkgs.jq ];
          text = ''
            online=$(tailscale status --json | jq -r '[.Self] + [.Peer[]?] | .[] | select(.Online) | .DNSName | split(".")[0]')
            targets=()
            for host in ${lib.escapeShellArgs (lib.attrNames hosts)}; do
              if grep -qx "$host" <<< "$online"; then
                targets+=(".#$host")
              else
                echo "deploy-online: skipping $host, offline" >&2
              fi
            done
            [ ''${#targets[@]} -gt 0 ] || { echo "deploy-online: no host is online" >&2; exit 1; }
            exec ${config.apps.deploy.program} --targets "''${targets[@]}" "$@"
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
