{
  config,
  lib,
  inputs,
  ...
}:
let
  inherit (lib) mkOption types;
  hosts = config.fleet.hosts;
  tracks = {
    stable = inputs.nixpkgs-stable;
    unstable = inputs.nixpkgs;
  };
  evaluated = lib.mapAttrs (
    name: host:
    tracks.${host.track}.lib.nixosSystem {
      modules = [
        config.flake.modules.nixos.base
        host.module
        {
          networking.hostName = name;
          nixpkgs.hostPlatform = host.system;
          fleet.bootstrap.approved = host.ready;
        }
      ]
      ++ map (capability: config.flake.modules.nixos.${capability}) host.capabilities;
    }
  ) hosts;
in
{
  options.fleet.hosts = mkOption {
    description = "Explicit identities and compositions. Directory placement has no semantic effect.";
    default = { };
    type = types.attrsOf (
      types.submodule {
        options = {
          system = mkOption {
            type = types.enum [ "x86_64-linux" ];
            description = "Required architecture; extend platform tests and CI before widening this type.";
          };
          track = mkOption {
            type = types.enum [
              "stable"
              "unstable"
            ];
            description = "Required primary Nixpkgs input. Never inferred from a role or directory.";
          };
          capabilities = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Names of deferred flake.modules.nixos values to compose.";
          };
          module = mkOption {
            type = types.deferredModuleWith { staticModules = [ { _class = "nixos"; } ]; };
            default = { };
            description = "Host-specific facts, merged by independent top-level features.";
          };
          ready = mkOption {
            type = types.bool;
            default = false;
            description = "Explicit commissioning approval. Missing facts still block builds.";
          };
        };
      }
    );
  };

  config.flake = {
    # These values remain inspectable even when a machine cannot safely be built.
    fleetConfigurations = evaluated;
    nixosConfigurations = lib.filterAttrs (name: _: hosts.${name}.ready) evaluated;
    fleet = lib.mapAttrs (
      name: host:
      let
        system = evaluated.${name};
        cfg = system.config;
        input = tracks.${host.track};
      in
      assert lib.assertMsg
        (
          ((cfg.fleet ? osDisk) || (cfg.fleet ? existingStorage))
          && (cfg.environment ? persistence)
          && (cfg.environment.persistence ? "/persist")
        )
        "${name}: the fleet inventory requires an existing-storage or OS-disk interface and /persist persistence capability; compose them or adapt the inventory with a new storage design.";
      {
        inherit (host)
          system
          track
          capabilities
          ready
          ;
        input = if host.track == "stable" then "nixpkgs-stable" else "nixpkgs";
        revision = input.rev;
        nixpkgsPath = toString system.pkgs.path;
        intendedNixpkgsPath = toString input.outPath;
        nixosVersion = cfg.system.nixos.version;
        missing = cfg.fleet.bootstrap.missing;
        failedAssertions = map (a: a.message) (lib.filter (a: !a.assertion) cfg.assertions);
        storageMode = if cfg.fleet ? existingStorage then "existing" else "provision";
        osDisk =
          if cfg.fleet ? existingStorage then cfg.fleet.existingStorage.osDevice else cfg.fleet.osDisk.device;
        filesystems = lib.mapAttrs (_: fs: {
          inherit (fs)
            device
            fsType
            options
            neededForBoot
            ;
        }) cfg.fileSystems;
        persistence = {
          directories = map (d: d.dirPath) cfg.environment.persistence."/persist".directories;
          files = map (f: f.filePath) cfg.environment.persistence."/persist".files;
        };
      }
    ) hosts;
  };
}
