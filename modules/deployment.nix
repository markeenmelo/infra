{
  config,
  lib,
  inputs,
  ...
}:
let
  inherit (lib) mkOption types;
  hosts = config.fleet.hosts;
  nixosModules = config.flake.modules.nixos;
  # Scoped overlay: never installed into a host's nixpkgs.overlays. The activation
  # helper AND its executable are built with the target's own pkgs, not another track.
  deploymentPkgs = pkgs: pkgs.extend inputs.deploy-rs.overlays.default;
  deployLib = pkgs: (deploymentPkgs pkgs).deploy-rs.lib;
  mkNode = name: host: {
    inherit (host.deployment)
      hostname
      sshUser
      interactiveSudo
      sudo
      fastConnection
      remoteBuild
      activationTimeout
      confirmTimeout
      ;
    sshOpts = [
      "-p"
      (toString host.deployment.sshPort)
      "-o"
      "ConnectTimeout=15"
      "-o"
      "ServerAliveInterval=10"
      "-o"
      "ServerAliveCountMax=3"
    ]
    ++ host.deployment.sshOpts;
    autoRollback = true;
    magicRollback = true;
    profiles.system = {
      user = host.deployment.profileUser;
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
              description = "Opt into deploy-rs targeting; offline desktops are opt-in.";
            };
            hostname = mkOption {
              type = types.nullOr (types.strMatching "[a-zA-Z0-9][a-zA-Z0-9.:%_-]*");
              default = null;
              description = "Real SSH endpoint or SSH config alias. null is an unresolved address, not a usable target.";
            };
            sshUser = mkOption {
              type = types.nullOr (types.strMatching "[a-z_][a-z0-9_-]*");
              default = null;
              description = "Real non-root SSH account; root SSH login is disabled. Provision keys and privilege escalation to the root activation account before deployment.";
            };
            transport = mkOption {
              type = types.nullOr (
                types.enum [
                  "trusted-user"
                  "signed"
                ]
              );
              default = null;
              description = "Explicit closure trust: trusted-user grants root-equivalent Nix trust; signed requires separately provisioned target trust keys and LOCAL_KEY on the operator.";
            };
            sshPort = mkOption {
              type = types.port;
              default = 22;
              description = "Chosen SSH service port; a policy default, not an observed hardware fact.";
            };
            profileUser = mkOption {
              type = types.strMatching "[a-z_][a-z0-9_-]*";
              default = "root";
              description = "Activation account. NixOS system profiles require root.";
            };
            sudo = mkOption {
              type = types.enum [
                "sudo -u"
                "doas -u"
              ];
              default = "sudo -u";
              description = "Privilege escalation command; run0 is not supported upstream.";
            };
            interactiveSudo = mkOption {
              type = types.bool;
              default = true;
              description = "Prompt for sudo by default; disable only after reviewing root-equivalent unattended access.";
            };
            sshOpts = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "Additional trusted operator-supplied SSH arguments; never disable host-key checking casually.";
            };
            fastConnection = mkOption {
              type = types.bool;
              default = false;
              description = "Push complete closures instead of target substitution.";
            };
            remoteBuild = mkOption {
              type = types.bool;
              default = false;
              description = "Opt into building on this target instead of the administration machine.";
            };
            activationTimeout = mkOption {
              type = types.ints.positive;
              default = 300;
              description = "Seconds allowed for activation.";
            };
            confirmTimeout = mkOption {
              type = types.ints.positive;
              default = 60;
              description = "Seconds allowed to confirm activation before magic rollback.";
            };
          };
          config.module = { config, lib, ... }: {
            imports = lib.optional deployment.enable nixosModules.ssh;
            config = lib.mkIf deployment.enable {
              fleet.bootstrap.missing =
                lib.optional (deployment.hostname == null) "Supply deployment.hostname (real SSH endpoint)."
                ++ lib.optional (deployment.sshUser == null) "Supply deployment.sshUser and verify elevation."
                ++
                  lib.optional (deployment.transport == null)
                    "Choose deployment.transport and provision closure trust (root-equivalent trusted-user or signed)."
                ++ lib.optional (
                  deployment.hostname != null && lib.hasSuffix ".invalid" deployment.hostname
                ) "Replace the reserved .invalid deployment endpoint.";
              services.openssh.ports = [ deployment.sshPort ];
              nix.settings.trusted-users = lib.optional (
                deployment.transport == "trusted-user" && deployment.sshUser != null
              ) deployment.sshUser;
              assertions = [
                {
                  assertion = deployment.profileUser == "root";
                  message = "NixOS system deployment must activate as root.";
                }
                {
                  assertion = deployment.sshUser != "root";
                  message = "Deployment SSH user must be non-root; SSH root login is disabled.";
                }
                {
                  assertion =
                    deployment.sshUser == null
                    || (
                      config.users.users ? ${deployment.sshUser}
                      && config.users.users.${deployment.sshUser}.openssh.authorizedKeys.keys != [ ]
                    );
                  message = "Deployment SSH user must have an explicitly configured account and public keys.";
                }
              ];
            };
          };
        }
      )
    );
  };
  config = {
    flake.deploy.nodes = lib.mapAttrs mkNode (
      lib.filterAttrs (_: host: host.ready && host.deployment.enable) hosts
    );
    flake.deploymentPlan = lib.mapAttrs (_: host: host.deployment // { inherit (host) ready; }) hosts;
    perSystem = { pkgs, ... }: {
      packages.deploy-rs = (deploymentPkgs pkgs).deploy-rs.deploy-rs;
      checks = (deployLib pkgs).deployChecks config.flake.deploy;
    };
  };
}
