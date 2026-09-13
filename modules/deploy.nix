{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
  hosts = config.fleet.hosts;
  nixosModules = config.flake.modules.nixos;
  deploymentPkgs = pkgs: pkgs.extend inputs.deploy-rs.overlays.default;
  deployLib = pkgs: (deploymentPkgs pkgs).deploy-rs.lib;
  groupNames = [
    "servers"
    "workstations"
  ];
  orderedHosts =
    group:
    lib.sort (
      a: b:
      if hosts.${a}.deployment.order == hosts.${b}.deployment.order then
        a < b
      else
        hosts.${a}.deployment.order < hosts.${b}.deployment.order
    ) (lib.attrNames (lib.filterAttrs (_: host: host.deployment.group == group) hosts));
  mkNode = name: host: {
    inherit (host.deployment)
      hostname
      sshUser
      remoteBuild
      activationTimeout
      confirmTimeout
      ;
    groups = [ host.deployment.group ];
    sudo = "sudo -n -u";
    interactiveSudo = false;
    autoRollback = true;
    magicRollback = true;
    tempPath = "/run/deploy-rs";
    sshOpts = [
      "-p"
      (toString host.deployment.sshPort)
      "-o"
      "BatchMode=yes"
      "-o"
      "StrictHostKeyChecking=yes"
      "-o"
      "UpdateHostKeys=no"
      "-o"
      "IdentityAgent=none"
      "-o"
      "IdentitiesOnly=yes"
      "-o"
      "ForwardAgent=no"
      "-o"
      "ClearAllForwardings=yes"
      "-o"
      "ConnectTimeout=15"
      "-o"
      "ServerAliveInterval=10"
      "-o"
      "ServerAliveCountMax=3"
    ];
    profiles.system = {
      user = "root";
      path =
        (deployLib config.flake.fleetConfigurations.${name}.pkgs).activate.nixos
          config.flake.fleetConfigurations.${name};
    };
  };
in
{
  options.fleet.hosts = mkOption {
    type = types.attrsOf (
      types.submodule (
        { config, ... }:
        let
          inherit (config) deployment;
        in
        {
          options.deployment = {
            enable = mkOption {
              type = types.bool;
              default = false;
              description = "Opt into deploy-rs targeting independently of local configuration readiness.";
            };
            hostname = mkOption {
              type = types.nullOr (types.strMatching "[a-zA-Z0-9][a-zA-Z0-9.:%_-]*");
              default = null;
              description = "Reviewed SSH endpoint or alias; null is not a target.";
            };
            sshUser = mkOption {
              type = types.nullOr (types.strMatching "[a-z_][a-z0-9_-]*");
              default = "deploy";
              description = "Dedicated key-only account. Verify its installed login and privileges on the host before deployment; nothing here proves them.";
            };
            sshPort = mkOption {
              type = types.port;
              default = 22;
              description = "Reviewed SSH service port.";
            };
            group = mkOption {
              type = types.nullOr (types.enum groupNames);
              default = null;
              description = "Explicit deployment group, independent of package track.";
            };
            order = mkOption {
              type = types.ints.positive;
              default = 100;
              description = "Sequential operator-runner order within the group; native group filtering alone does not enforce order.";
            };
            remoteBuild = mkOption {
              type = types.bool;
              default = true;
              description = "Build on the target's ssh-ng store using the explicitly trusted deployment account.";
            };
            bootOnly = mkOption {
              type = types.bool;
              default = false;
              description = "Operator runner must use boot-only activation until the access/home transition is accepted.";
            };
            activationTimeout = mkOption {
              type = types.ints.positive;
              default = 300;
              description = "Seconds allowed for activation.";
            };
            confirmTimeout = mkOption {
              type = types.ints.positive;
              default = 60;
              description = "Seconds allowed for magic-rollback confirmation.";
            };
          };
          config.module = { lib, ... }: {
            imports = lib.optional deployment.enable nixosModules.deploy;
            config = lib.mkIf deployment.enable {
              fleet.bootstrap.missing =
                lib.optional (deployment.hostname == null) "Supply deployment.hostname (real SSH endpoint)."
                ++ lib.optional (deployment.sshUser == null) "Supply deployment.sshUser and verify elevation."
                ++ lib.optional (deployment.group == null) "Choose deployment.group."
                ++ lib.optional (
                  deployment.hostname != null && lib.hasSuffix ".invalid" deployment.hostname
                ) "Replace the reserved .invalid deployment endpoint.";
              services.openssh.ports = [ deployment.sshPort ];
              assertions = [
                {
                  assertion = deployment.sshUser == "deploy" && deployment.remoteBuild;
                  message = "Fleet deployment requires the dedicated deploy account and remote builds.";
                }
              ];
            };
          };
        }
      )
    );
  };

  config = {
    flake.modules.nixos.deploy =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        keys = map (key: "restrict ${key}") config.fleet.access.authorizedKeys;
        commands = [
          "/nix/store/*-activatable-nixos-system-*/activate-rs"
          "${pkgs.coreutils}/bin/rm ^/run/deploy-rs/deploy-rs-canary-[0-9abcdfghijklmnpqrsvwxyz]{32}$"
        ];
        sudoRule = {
          users = [ "deploy" ];
          runAs = "root";
          commands = map (command: {
            inherit command;
            options = [ "NOPASSWD" ];
          }) commands;
        };
      in
      {
        key = "fleet.deploy";
        imports = [
          nixosModules.access
          nixosModules.ssh
        ];
        config = {
          fleet.access.deploymentUser = "deploy";
          users.groups.deploy = { };
          users.users.deploy = {
            isSystemUser = true;
            group = "deploy";
            extraGroups = [ "wheel" ];
            home = "/var/lib/deploy";
            createHome = true;
            homeMode = "700";
            shell = pkgs.bash;
            hashedPassword = "!";
            openssh.authorizedKeys.keys = keys;
          };
          security.sudo.extraRules = [ sudoRule ];
          nix.settings = {
            trusted-users = [ "deploy" ];
            build-dir = "/nix/var/nix/builds";
          };
          systemd.tmpfiles.rules = [
            "d /run/deploy-rs 0700 root root -"
            "d /nix/var/nix/builds 0700 root root -"
          ];
          assertions = [
            {
              assertion =
                keys != [ ]
                && config.users.users.deploy.isSystemUser
                && !config.users.users.deploy.isNormalUser
                && config.users.users.deploy.hashedPassword == "!"
                && config.users.users.deploy.hashedPasswordFile == null
                && config.users.users.deploy.password == null
                && config.users.users.deploy.initialPassword == null
                && config.users.users.deploy.initialHashedPassword == null
                && config.users.users.deploy.group == "deploy"
                && config.users.users.deploy.home == "/var/lib/deploy"
                && config.users.users.deploy.createHome
                && config.users.users.deploy.homeMode == "700"
                && config.users.users.deploy.openssh.authorizedKeys.keyFiles == [ ]
                && config.users.users.deploy.extraGroups == [ "wheel" ]
                && config.users.users.deploy.openssh.authorizedKeys.keys == keys
                && lib.elem "deploy" config.nix.settings.trusted-users
                && !(lib.elem "@wheel" config.nix.settings.trusted-users)
                && config.nix.settings.require-sigs
                && config.security.sudo.wheelNeedsPassword
                && !config.security.sudo.execWheelOnly
                && lib.any (
                  rule:
                  rule.users == [ "deploy" ]
                  && rule.runAs == "root"
                  && map (command: command.command) rule.commands == commands
                  && lib.all (command: command.options == [ "NOPASSWD" ]) rule.commands
                ) config.security.sudo.extraRules;
              message = "Deployment requires restricted SSH keys, locked dedicated account, explicit root-equivalent Nix trust and its passwordless activation/confirmation rules.";
            }
          ];
        };
      };

    fleet.hosts = lib.mkMerge [
      (lib.genAttrs [ "racknerd" "bastion" "thinkpad" ] (_: {
        capabilities = [ "deploy" ];
      }))
      {
        racknerd = {
          deployment = {
            enable = true;
            hostname = "72.11.150.242";
            group = "servers";
            order = 10;
          };
          module.nix.settings.trusted-public-keys = [
            "racknerd-deploy-20260912:dJ7er88VXs6+ZiVlGu1LTnlXc+EujXsqdVYb3Grh2Ak="
          ];
        };
        bastion = {
          deployment = {
            enable = true;
            hostname = "192.168.2.2";
            bootOnly = true;
            group = "servers";
            order = 20;
          };
          module.nix.settings.trusted-public-keys = [
            "bastion-deploy-20260912:FYekV+z8HC3dmaBay30ThuDpgGWrWoLolsSRNs+2dJs="
          ];
        };
        thinkpad.deployment = {
          enable = false;
          group = "workstations";
        };
      }
    ];

    flake = {
      deploy.nodes = lib.mapAttrs mkNode (
        lib.filterAttrs (_: host: host.ready && host.deployment.enable) hosts
      );
      deploymentGroups = lib.genAttrs groupNames orderedHosts;
      deploymentPlan = lib.mapAttrs (
        _: host:
        host.deployment
        // {
          inherit (host) ready;
          profileUser = "root";
          transport = "trusted-user";
          sudo = "sudo -n -u";
          interactiveSudo = false;
          autoRollback = true;
          magicRollback = true;
        }
      ) hosts;
    };
    perSystem = { pkgs, ... }: {
      packages.deploy-rs = (deploymentPkgs pkgs).deploy-rs.deploy-rs;
    };
  };
}
