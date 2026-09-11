{ config, lib, ... }:
let
  fleet = config;
  # Enable only the individually reviewed host, never the entire fleet at once.
  rollout = {
    thinkpad = true;
    racknerd = false;
    bastion = false;
  };
  hosts = builtins.attrNames rollout;
in
{
  # Deliberately staged: composing the capability records intent, but cannot
  # change an installed machine until that machine's rollout is enabled.
  fleet.hosts = lib.genAttrs hosts (name: {
    capabilities = [ "tailscale" ];
    module.fleet.tailscale = {
      enable = rollout.${name};
      tag = "tag:fleet-${name}";
    };
  });

  flake.tailscalePlan = lib.genAttrs hosts (
    name:
    let
      cfg = fleet.flake.fleetConfigurations.${name}.config.fleet.tailscale;
    in
    {
      inherit (cfg)
        enable
        tag
        enrollmentMode
        missing
        ;
    }
  );

  flake.modules.nixos.tailscale =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.fleet.tailscale;
      secret =
        if cfg.authKeySecret == null then null else config.sops.secrets.${cfg.authKeySecret} or null;
      keyPath = if secret == null then "" else secret.path;
      missing =
        lib.optional (cfg.tag == null) "Supply this device's unique admin-controlled Tailscale tag."
        ++ lib.optional (
          cfg.enrollmentMode == null
        ) "Choose Tailscale auth-key enrollment or preservation of a verified existing node."
        ++ lib.optional (
          !cfg.stateReviewed
        ) "Review Tailscale identity, backing-state migration, permissions and recovery."
        ++
          lib.optional (!cfg.policyReviewed)
            "Verify the intended tailnet, applied default-deny policy and unique tag assignment before enrollment."
        ++ lib.optional (
          cfg.enrollmentMode == "auth-key" && secret == null
        ) "Declare a per-host SOPS Tailscale auth-key secret and select fleet.tailscale.authKeySecret.";
    in
    {
      key = "fleet.tailscale";
      imports = [ fleet.flake.modules.nixos.secrets ];
      options.fleet.tailscale = {
        enable = lib.mkEnableOption "the separately reviewed Tailscale rollout (not host commissioning)";
        tag = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum (map (name: "tag:fleet-${name}") hosts));
          default = null;
          description = "Exactly one device may receive this tag. Family members must not own fleet tags.";
        };
        enrollmentMode = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.enum [
              "auth-key"
              "preserve"
            ]
          );
          default = null;
          description = "Preserve requires an already authenticated node; auth-key enrolls only when NeedsLogin, never forces reauthentication.";
        };
        authKeySecret = lib.mkOption {
          type = lib.types.nullOr (lib.types.strMatching "[a-zA-Z0-9_-]+");
          default = null;
          description = "Declared SOPS secret name, not a key or an arbitrary filesystem path.";
        };
        stateReviewed = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Actual existing node/backing-state and migration/recovery review, not successful evaluation.";
        };
        policyReviewed = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Intended tailnet, live policy and narrowly scoped key/tag assignment have actually been reviewed.";
        };
        missing = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          readOnly = true;
          description = "Visible rollout prerequisites even while disabled; enforced as bootstrap blockers when enabled.";
        };
      };
      config = lib.mkMerge [
        {
          fleet.tailscale.missing = missing;
          fleet.bootstrap.missing = lib.optionals cfg.enable missing;
          services.tailscale.enable = cfg.enable;
          assertions = [
            {
              assertion = config.services.tailscale.enable == cfg.enable;
              message = "Use fleet.tailscale.enable so native daemon activation cannot bypass rollout review.";
            }
          ];
        }
        (lib.mkIf cfg.enable {
          services.tailscale = {
            openFirewall = true;
            disableTaildrop = true;
          };
          environment.persistence."/persist".directories = [
            {
              directory = "/var/lib/tailscale";
              user = "root";
              group = "root";
              mode = "0700";
            }
          ];
          systemd.services = {
            tailscaled.unitConfig.RequiresMountsFor = [
              "/persist/var/lib/tailscale"
              "/var/lib/tailscale"
            ];
            # Native autoconnect embeds the key value in argv. The assertion
            # below keeps it disabled; this unit uses the CLI's file: argument.
            fleet-tailscale = {
              description = "Reconcile reviewed Tailscale client enrollment and preferences";
              wantedBy = [ "multi-user.target" ];
              # SOPS uses activation scripts here, not a boot-time service.
              # Those scripts finish before units start; a missing auth key
              # still makes the CLI fail closed when enrollment is required.
              after = [
                "tailscaled.service"
                "network-online.target"
              ];
              wants = [ "network-online.target" ];
              requires = [ "tailscaled.service" ];
              unitConfig = {
                StartLimitIntervalSec = 600;
                StartLimitBurst = 3;
              };
              path = [
                config.services.tailscale.package
                pkgs.jq
                pkgs.coreutils
              ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                TimeoutStartSec = 120;
                Restart = "on-failure";
                RestartSec = 30;
                UMask = "0077";
              };
              script = ''
                ${pkgs.bash}/bin/bash ${./reconcile.sh} ${
                  lib.escapeShellArgs [
                    (if cfg.enrollmentMode == null then "unconfigured" else cfg.enrollmentMode)
                    config.networking.hostName
                    (if cfg.tag == null then "unconfigured" else cfg.tag)
                    keyPath
                  ]
                }
              '';
            };
          };
          assertions = [
            {
              assertion = cfg.tag == "tag:fleet-${config.networking.hostName}";
              message = "Tailscale tag must identify this host, not another fleet member.";
            }
            {
              assertion = cfg.enrollmentMode != "preserve" || cfg.authKeySecret == null;
              message = "Preserved Tailscale nodes must not carry enrollment credentials.";
            }
            {
              assertion =
                secret == null
                || (
                  lib.elem secret.owner [
                    null
                    "root"
                  ]
                  && lib.elem secret.group [
                    null
                    "root"
                  ]
                  && secret.uid == 0
                  && secret.gid == 0
                  && secret.mode == "0400"
                  && !secret.neededForUsers
                  && secret.path == "/run/secrets/${cfg.authKeySecret}"
                  && lib.elem "fleet-tailscale.service" secret.restartUnits
                );
              message = "Tailscale enrollment needs a root-only runtime SOPS secret with fleet-tailscale.service in restartUnits, never a store/manual/early-user credential.";
            }
            {
              assertion =
                config.services.tailscale.authKeyFile == null
                && config.services.tailscale.extraUpFlags == [ ]
                && config.services.tailscale.extraSetFlags == [ ]
                && config.services.tailscale.extraDaemonFlags == [ ]
                && config.services.tailscale.useRoutingFeatures == "none"
                && config.services.tailscale.interfaceName == "tailscale0"
                && config.services.tailscale.port == 41641
                && config.services.tailscale.disableTaildrop
                && config.services.tailscale.permitCertUid == null;
              message = "Fleet Tailscale owns client preferences: no competing enrollment, SSH, routing, operator, Serve or daemon overrides.";
            }
            {
              assertion =
                (config.fileSystems."/persist".neededForBoot or false)
                && !(lib.elem "tailscale0" config.networking.firewall.trustedInterfaces);
              message = "Tailscale requires early persistent state and must not blanket-trust its interface.";
            }
          ];
        })
      ];
    };
}
