{
  config,
  lib,
  inputs,
  ...
}:
let
  hosts = lib.filterAttrs (_: host: !lib.hasSuffix "-darwin" host.system) config.fleet.hosts;
  systems = lib.unique (lib.mapAttrsToList (_: host: host.system) hosts);
in
{
  flake = {
    deploy.nodes = lib.mapAttrs (name: host: {
      hostname = name;
      sshUser = "deploy";
      remoteBuild =
        host.system != config.fleet.hosts.bastion.system
        || config.flake.nixosConfigurations.${name}.config.nix.sshServe.enable;
      profiles.system = {
        user = "root";
        path = inputs.deploy-rs.lib.${host.system}.activate.nixos config.flake.nixosConfigurations.${name};
      };
    }) hosts;

    checks = lib.genAttrs systems (
      system:
      inputs.deploy-rs.lib.${system}.deployChecks {
        nodes = lib.filterAttrs (
          name: _: config.fleet.hosts.${name}.system == system
        ) config.flake.deploy.nodes;
      }
    );

    modules.nixos.base = {
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
          ];
        }
      ];
    };
  };

  perSystem =
    {
      lib,
      pkgs,
      inputs',
      ...
    }:
    {
      apps.deploy = {
        meta.description = "deploy .#HOST: activate the host's committed configuration over the tailnet with magic rollback";
        program = lib.getExe inputs'.deploy-rs.packages.deploy-rs;
      };
      apps.reboot = {
        meta.description = "reboot HOST: reboot a NixOS host over the tailnet as the deploy account, e.g. after deploy --boot";
        program = pkgs.writeShellApplication {
          name = "reboot";
          runtimeInputs = [ pkgs.openssh ];
          text = ''
            case ''${1-} in
            ${
              lib.concatMapStrings (name: "  ${name}) ;;\n") (lib.attrNames hosts)
            }  *) echo "reboot: no NixOS host named ''${1-}" >&2; exit 1 ;;
            esac
            ssh "deploy@$1" sudo /run/current-system/sw/bin/systemctl reboot
          '';
        };
      };
    };
}
