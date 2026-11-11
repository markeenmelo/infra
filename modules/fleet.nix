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
  octet = "(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])";
  ipv4 = lib.types.strMatching "${octet}(\\.${octet}){3}";
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
            type = lib.types.strMatching "100\\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\\.${octet}\\.${octet}";
            description = "The host's Tailscale IPv4 address, kept across reinstalls by its carried tailnet identity; the `tofu` app hands it to `opentofu/tailscale` as `fleet_hosts`.";
          };
          publicAddress = lib.mkOption {
            type = lib.types.nullOr ipv4;
            default = null;
            description = "The host's public IPv4 address, for a host the internet reaches; the `tofu` app hands the edge's to `opentofu/porkbun` as `fleet_edge_address`, and bastion probes each from outside.";
          };
          lan = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.submodule {
                options = {
                  address = lib.mkOption {
                    type = ipv4;
                    description = "IPv4 address the host holds on its LAN.";
                  };
                  gateway = lib.mkOption {
                    type = ipv4;
                    description = "The LAN's UniFi gateway, which is also its controller.";
                  };
                  mac = lib.mkOption {
                    type = lib.types.strMatching "([0-9a-f]{2}:){5}[0-9a-f]{2}";
                    description = "MAC address of the uplink, which the gateway fixes `address` to.";
                  };
                  syslogPort = lib.mkOption {
                    type = lib.types.port;
                    description = "UDP port on `address` that takes the gateway's syslog.";
                  };
                  routes = lib.mkOption {
                    type = lib.types.attrsOf (lib.types.strMatching "${octet}(\\.${octet}){3}/(3[0-2]|[12]?[0-9])");
                    description = "LAN subnets, by name, the host advertises to the tailnet as their router; the `tofu` app hands them to `opentofu/tailscale` as `fleet_routes`.";
                  };
                };
              }
            );
            default = null;
            description = "A host wired to the LAN at a fixed address; the `tofu` app hands these to `opentofu/unifi` as `fleet_lan`.";
          };
          telemetry = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.submodule {
                options = {
                  metrics = lib.mkOption {
                    type = lib.types.nullOr lib.types.port;
                    description = "Port on bastion's tailnet address that takes this host's remote-written metrics; null for a host that ships only logs, which gets no `Host silent` alert.";
                  };
                  logs = lib.mkOption {
                    type = lib.types.port;
                    description = "Port on bastion's tailnet address that takes this host's pushed logs.";
                  };
                };
              }
            );
            default = null;
            description = "Ports a host that imports `telemetry` or `logs` pushes to; bastion's Alloy listens on each, stamps the host label and admits only that host's tailnet address.";
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
