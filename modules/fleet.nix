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
        }
      ];
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
            description = "Required architecture.";
          };
          track = mkOption {
            type = types.enum [
              "stable"
              "unstable"
            ];
            description = "Required primary Nixpkgs input. Never inferred from a role or directory.";
          };
          module = mkOption {
            type = types.deferredModuleWith { staticModules = [ { _class = "nixos"; } ]; };
            default = { };
            description = "Host facts and the named flake.modules.nixos values it imports, merged by independent top-level features.";
          };
        };
      }
    );
  };

  config.flake = {
    nixosConfigurations = evaluated;
    fleet = lib.mapAttrs (
      name: host:
      let
        system = evaluated.${name};
        cfg = system.config;
        input = tracks.${host.track};
      in
      {
        inherit (host) system track;
        input = if host.track == "stable" then "nixpkgs-stable" else "nixpkgs";
        revision = input.rev;
        nixpkgsPath = toString system.pkgs.path;
        intendedNixpkgsPath = toString input.outPath;
        nixosVersion = cfg.system.nixos.version;
        failedAssertions = map (a: a.message) (lib.filter (a: !a.assertion) cfg.assertions);
        osDisk = cfg.fleet.installation.osDevice;
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
