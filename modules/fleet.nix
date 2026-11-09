{
  config,
  lib,
  inputs,
  ...
}:
let
  isDarwin = host: lib.hasSuffix "-darwin" host.system;
  nixosHosts = lib.filterAttrs (_: host: !isDarwin host) config.fleet.hosts;
  darwinHosts = lib.filterAttrs (_: host: isDarwin host) config.fleet.hosts;
in
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
              "aarch64-darwin"
            ];
            default = "x86_64-linux";
            description = "Nix system the host runs; sets `nixpkgs.hostPlatform`.";
          };
          tailnetAddress = lib.mkOption {
            # Tailscale's CGNAT range, 100.64.0.0/10
            type = lib.types.strMatching "100\\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\\.[0-9]{1,3}\\.[0-9]{1,3}";
            description = "The host's Tailscale IPv4 address, kept across reinstalls by its carried tailnet identity; the `tofu` app hands it to `opentofu/tailscale` as `fleet_hosts`.";
          };
          module = lib.mkOption {
            type = lib.types.deferredModuleWith { staticModules = [ { _class = "nixos"; } ]; };
            default = { };
            description = "Host facts, the named `flake.modules.nixos` values it imports, and host-only contributions from concerns.";
          };
          darwin = lib.mkOption {
            type = lib.types.deferredModuleWith { staticModules = [ { _class = "darwin"; } ]; };
            default = { };
            description = "nix-darwin counterpart of `module`, used when `system` is a darwin one.";
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
    ) nixosHosts;

    darwinConfigurations = lib.mapAttrs (
      name: host:
      inputs.nix-darwin.lib.darwinSystem {
        modules = [
          config.flake.modules.darwin.base
          host.darwin
          {
            networking.hostName = name;
            nixpkgs.hostPlatform = host.system;
          }
        ];
      }
    ) darwinHosts;

    checks = lib.foldlAttrs (
      acc: name: host:
      lib.recursiveUpdate acc {
        ${host.system} =
          if !isDarwin host then
            let
              build = config.flake.nixosConfigurations.${name}.config.system.build;
            in
            {
              "host-${name}" = build.toplevel;
              "disko-${name}" = build.diskoScript;
            }
          else
            {
              "darwin-${name}" = config.flake.darwinConfigurations.${name}.config.system.build.toplevel;
            };
      }
    ) { } config.fleet.hosts;
  };
}
