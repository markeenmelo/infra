{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
  tests = config.fleet.validation;
  reports = config.flake.validation;
  tracks = {
    stable = inputs.nixpkgs-stable;
    unstable = inputs.nixpkgs-unstable;
  };
in
{
  options = {
    fleet.validation = {
      expectedTracks = mkOption {
        type = types.attrsOf (
          types.enum [
            "stable"
            "unstable"
          ]
        );
        readOnly = true;
        description = "Independent required-host track oracle; never used to select production inputs.";
      };
      fixtureModules = mkOption {
        type = types.attrsOf (types.functionTo types.deferredModule);
        default = { };
        description = "Evaluation-only facts by capability; each constructor receives the fixture boot mode. Never imported by real hosts.";
      };
      fixtureFor = mkOption {
        type = types.functionTo (types.functionTo (types.functionTo types.raw));
        description = "track -> bootMode -> capability names -> opaque synthetic NixOS evaluation.";
      };
      allCapabilities = mkOption {
        type = types.listOf types.str;
        description = "Explicit combined infrastructure fixture, not every exported capability.";
      };
      fixtures = mkOption {
        type = types.lazyAttrsOf types.raw;
        description = "Shared opaque infrastructure evaluations, one per independently required track.";
      };
      hostChecks = mkOption {
        type = types.attrsOf (types.functionTo types.bool);
        default = { };
        description = "Feature-owned predicates receiving { name, host, system }; all are forced by validation.hosts and readiness preflight.";
      };
    };
    flake.validation = mkOption {
      type = types.submodule {
        freeformType = types.lazyAttrsOf types.raw;
        options.fixtures = mkOption {
          type = types.lazyAttrsOf (types.lazyAttrsOf types.raw);
          default = { };
          description = "Storage and deployment contribute independent fields to each fixture report.";
        };
      };
      default = { };
      description = "Merged, non-destructive evaluation reports contributed by their feature owners.";
    };
  };

  config = {
    fleet.validation = {
      expectedTracks = {
        thinkpad = "unstable";
        racknerd = "stable";
        bastion = "stable";
      };
      allCapabilities = [
        "os-disk"
        "headless"
        "persistence"
        "access"
        "server"
        "vps"
        "workstation"
        "laptop"
        "gaming"
        "nas"
        "administration"
        "tailscale"
      ];
      # Explicitly synthetic EVALUATION fixtures, never fleet/install/deploy targets.
      fixtureModules.base = _: { lib, pkgs, ... }: {
        nixpkgs.hostPlatform = "x86_64-linux";
        networking.hostName = "evaluation-fixture";
        fleet = {
          bootstrap.approved = true;
          installation = {
            stateVersion = lib.versions.majorMinor pkgs.lib.version;
            hardwareReviewed = true;
            networkReviewed = true;
          };
        };
      };
      fixtureFor =
        track: bootMode: capabilities:
        tracks.${track}.lib.nixosSystem {
          modules = [
            config.flake.modules.nixos.base
            (tests.fixtureModules.base bootMode)
          ]
          ++ map (name: config.flake.modules.nixos.${name}) capabilities
          # Only the requested capabilities get facts. Importing every fixture
          # contribution would hide missing dependencies in exact-subset tests.
          ++ map (name: (tests.fixtureModules.${name} or (_: { })) bootMode) capabilities;
        };
      fixtures = lib.genAttrs (builtins.attrNames tracks) (
        track: tests.fixtureFor track "uefi" tests.allCapabilities
      );
    };

    perSystem = { config, pkgs, ... }: {
      # Independent coverage inventory: deleting an owner must not silently turn
      # a smaller aggregate into a successful validation result.
      checks.fleet-evaluation =
        assert lib.assertMsg (
          builtins.attrNames reports == [
            "compositions"
            "desktop"
            "existingInstallations"
            "fixtures"
            "hosts"
            "sops"
            "tailscale"
            "wifi"
          ]
        ) "An evaluation suite is missing; review the independent report inventory.";
        assert lib.assertMsg (
          builtins.attrNames config.checks == [
            "bastion-import-policy"
            "bastion-tailscale-manifest"
            "deploy-activate"
            "deploy-schema"
            "fleet-evaluation"
            "pi-extensions"
            "secret-files"
            "senecanet-template-manifest"
            "shared-password-recipients"
            "source-quality"
            "stable-deploy-activate-smoke"
            "stable-deploy-schema-smoke"
            "stable-sops-users-manifest"
            "stable-tailscale-cli"
            "tailscale-offline"
            "thinkpad-desktop-config"
            "thinkpad-output-policy"
            "thinkpad-printer-provisioning"
            "thinkpad-wifi-manifest"
            "unstable-deploy-activate-smoke"
            "unstable-deploy-schema-smoke"
            "unstable-desktop-config"
            "unstable-sops-users-manifest"
            "unstable-tailscale-cli"
            "wifi-secret-environment"
          ]
        ) "A built check is missing; review the independent check inventory.";
        # Discard ONLY metadata context after forcing the reports. Fixtures are
        # evaluated, not built as system closures or exported as install targets.
        pkgs.writeText "fleet-evaluation.json" (
          builtins.unsafeDiscardStringContext (builtins.toJSON reports)
        );
    };
  };
}
