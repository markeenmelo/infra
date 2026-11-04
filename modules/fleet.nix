{
  config,
  lib,
  inputs,
  ...
}:
{
  options.fleet.hosts = lib.mkOption {
    description = "Fleet members; `modules/hosts/NAME/` is the only writer of `fleet.hosts.NAME`.";
    default = { };
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          system = lib.mkOption {
            type = lib.types.enum [
              "x86_64-linux"
              "aarch64-linux"
            ];
            default = "x86_64-linux";
            description = "Nix system the host runs; sets `nixpkgs.hostPlatform`.";
          };
          module = lib.mkOption {
            type = lib.types.deferredModuleWith { staticModules = [ { _class = "nixos"; } ]; };
            default = { };
            description = "Host facts, the named `flake.modules.nixos` values it imports, and host-only contributions from concerns.";
          };
        };
      }
    );
  };

  config.flake = {
    nixosConfigurations = lib.mapAttrs (
      name: host:
      inputs.nixpkgs.lib.nixosSystem {
        modules = [
          config.flake.modules.nixos.base
          host.module
          {
            networking.hostName = name;
            nixpkgs.hostPlatform = host.system;
          }
        ];
      }
    ) config.fleet.hosts;

    checks = lib.foldlAttrs (
      acc: name: host:
      let
        build = config.flake.nixosConfigurations.${name}.config.system.build;
      in
      lib.recursiveUpdate acc {
        ${host.system} = {
          "host-${name}" = build.toplevel;
          "disko-${name}" = build.diskoScript;
        };
      }
    ) { } config.fleet.hosts;
  };
}
