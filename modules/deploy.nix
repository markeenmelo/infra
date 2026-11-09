{
  config,
  lib,
  inputs,
  ...
}:
let
  hosts = lib.filterAttrs (_: host: !lib.hasSuffix "-darwin" host.system) config.fleet.hosts;
  systems = lib.unique (lib.mapAttrsToList (_: host: host.system) hosts);
  deployLib =
    system:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      input = (lib.importTOML "${inputs.deploy-rs}/Cargo.toml").package.version;
    in
    assert lib.assertMsg (pkgs.deploy-rs.version == input)
      "nixpkgs ships deploy-rs ${pkgs.deploy-rs.version} but the deploy-rs input is ${input}: move them together";
    (pkgs.appendOverlays [
      inputs.deploy-rs.overlays.default
      (_: prev: {
        deploy-rs = {
          inherit (prev.deploy-rs) lib;
          inherit (pkgs) deploy-rs;
        };
      })
    ]).deploy-rs.lib;
in
{
  flake = {
    deploy.nodes = lib.mapAttrs (name: host: {
      hostname = name;
      sshUser = "deploy";
      # shortcut: each server builds itself, switch to the bastion builder when it lands
      remoteBuild = true;
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
      { config, ... }:
      {
        users = {
          users.deploy = {
            isSystemUser = true;
            group = "deploy";
            useDefaultShell = true;
            openssh.authorizedKeys.keys = map (
              key: "restrict ${key}"
            ) config.users.users.marcos.openssh.authorizedKeys.keys;
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
            ];
          }
        ];
      };
  };

  perSystem =
    { lib, pkgs, ... }:
    {
      apps.deploy = {
        meta.description = "deploy .#HOST: activate the host's committed configuration over the tailnet with magic rollback";
        program = lib.getExe pkgs.deploy-rs;
      };
    };
}
