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
  sudo = {
    security.sudo-rs = {
      enable = true;
      extraRules = [
        {
          users = [ "deploy" ];
          runAs = "root";
          commands =
            map
              (command: {
                inherit command;
                options = [ "NOPASSWD" ];
              })
              [
                "/nix/store/*/activate-rs *"
                "/run/current-system/sw/bin/rm *"
                "/run/current-system/sw/bin/systemctl reboot"
                "/run/current-system/sw/bin/systemctl poweroff"
                ''${clean} ""''
              ];
        }
      ];
    };
  };
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

    checks = lib.mkMerge [
      (lib.genAttrs systems (
        system:
        (deployLib system).deployChecks {
          nodes = lib.filterAttrs (
            name: _: config.fleet.hosts.${name}.system == system
          ) config.flake.deploy.nodes;
        }
      ))
      {
        ${config.fleet.hosts.bastion.system}.deploy-sudo =
          let
            pkgs = inputs.nixpkgs.legacyPackages.${config.fleet.hosts.bastion.system};
            activate = pkgs.runCommand "probe" { } ''
              mkdir $out
              ln -s ${pkgs.writeShellScript "activate" "id -u"} $out/activate-rs
            '';
          in
          pkgs.testers.runNixOSTest {
            name = "deploy-sudo";
            nodes.machine = {
              imports = [ sudo ];
              users = {
                users.deploy = {
                  isSystemUser = true;
                  group = "deploy";
                  extraGroups = [ "wheel" ];
                };
                groups.deploy = { };
              };
              system.extraDependencies = [ activate ];
              environment.systemPackages = [ (pkgs.writeShellScriptBin "clean-generations" "echo cleaned") ];
              security.sudo-rs.execWheelOnly = true;
            };
            testScript = ''
              def deploy(command):
                  return f"runuser -u deploy -- sudo -n -u root {command}"

              def allowed(command):
                  return f"runuser -u deploy -- sudo -n -l -u root {command}"

              machine.wait_for_unit("multi-user.target")
              canary = "/tmp/deploy-rs-canary-" + "a1" * 16
              machine.succeed(f"touch {canary}")
              machine.succeed(deploy(f"rm {canary}"))
              machine.fail(f"test -e {canary}")
              assert machine.succeed(deploy("${activate}/activate-rs activate x")).strip() == "0"
              machine.fail(deploy("/run/current-system/sw/bin/systemctl status"))
              assert machine.succeed(deploy("${clean}")).strip() == "cleaned"
              machine.fail(deploy("${clean} now"))
              machine.succeed(allowed("/run/current-system/sw/bin/systemctl reboot"))
              machine.succeed(allowed("/run/current-system/sw/bin/systemctl poweroff"))
              machine.fail(allowed("/run/current-system/sw/bin/systemctl reboot now"))
              machine.fail(deploy("id"))
            '';
          };
      }
    ];

    modules.nixos.base =
      { config, pkgs, ... }:
      {
        imports = [ sudo ];
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
            pkgs.jaq
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
            online=$(tailscale status --json | jaq -r '[.Self] + [.Peer[]?] | .[] | select(.Online) | .TailscaleIPs[]?')
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
