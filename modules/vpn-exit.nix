{ config, ... }:
let
  inherit (config.flake.modules.nixos) vpn-watch;
  # subnet is the third octet of each tunnel's namespace subnet; region is the PIA region id
  countries = {
    ca = {
      subnet = 1;
      region = "ca_toronto";
    };
    us = {
      subnet = 2;
      region = "us-newjersey";
    };
    br = {
      subnet = 3;
      region = "br";
    };
  };
in
{
  flake.modules.nixos.vpn-exit =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      tailscale = lib.getExe config.services.tailscale.package;
      socket = country: "/run/tailscale-${country}/tailscaled.sock";
      perCountry = f: lib.mkMerge (lib.mapAttrsToList f countries);
    in
    {
      imports = [ vpn-watch ];

      sops.secrets = lib.mkMerge [
        (perCountry (
          country: _: {
            "vpn-exit-${country}-auth-key" = {
              key = "vpn-exit/${country}-auth-key";
              restartUnits = [ "tailscaled-${country}.service" ];
            };
          }
        ))
        (lib.genAttrs [ "pia-username" "pia-password" ] (name: {
          key = "pia/${lib.removePrefix "pia-" name}";
          restartUnits = map (country: "pv${country}.service") (lib.attrNames countries);
        }))
      ];
      fleet.piaCredentials = lib.genAttrs [ "username" "password" ] (
        field: config.sops.secrets."pia-${field}".path
      );

      vpnNamespaces = perCountry (
        country: tunnel: {
          "pv${country}" = {
            enable = true;
            piaRegion = tunnel.region;
            namespaceAddress = "10.200.${toString tunnel.subnet}.1";
            bridgeAddress = "10.200.${toString tunnel.subnet}.5";
          };
        }
      );

      # shortcut: tailscaled's own control, DERP and peer traffic also leaves through PIA, so peers mostly relay over DERP; route its fwmark over the bridge if throughput matters
      systemd.services = perCountry (
        country: _: {
          "tailscaled-${country}" = {
            description = "Tailscale exit node through PIA (${country})";
            wantedBy = [ "multi-user.target" ];
            vpnConfinement = {
              enable = true;
              vpnNamespace = "pv${country}";
            };
            serviceConfig = {
              Type = "notify";
              ExecStartPre = "${lib.getExe' pkgs.procps "sysctl"} -w net.ipv4.ip_forward=1 net.ipv6.conf.all.forwarding=1";
              ExecStart = "${lib.getExe' config.services.tailscale.package "tailscaled"} --statedir=/var/lib/tailscale-${country} --socket=${socket country} --tun=tailscale0 --port=41641";
              ExecStopPost = "${lib.getExe' config.services.tailscale.package "tailscaled"} --cleanup --statedir=/var/lib/tailscale-${country} --socket=${socket country}";
              Restart = "on-failure";
              RuntimeDirectory = "tailscale-${country}";
              StateDirectory = "tailscale-${country}";
              StateDirectoryMode = "0700";
            };
          };
          "tailscaled-${country}-set" = {
            description = "Join the tailnet and advertise the exit node (${country})";
            wants = [ "tailscaled-${country}.service" ];
            after = [ "tailscaled-${country}.service" ];
            wantedBy = [ "tailscaled-${country}.service" ];
            path = [ pkgs.jq ];
            enableStrictShellChecks = true;
            startLimitIntervalSec = 0;
            serviceConfig = {
              Type = "oneshot";
              Restart = "on-failure";
              RestartSec = 30;
              TimeoutStartSec = "5min";
            };
            script = ''
              ts() { ${tailscale} --socket=${socket country} "$@"; }
              prefs=(
                --hostname=vpn-${country}
                --advertise-exit-node=true
                --accept-dns=false
                --accept-routes=false
                --ssh=false
              )
              while state=$(ts status --json --peers=false | jq -r .BackendState); [[ $state == NoState || $state == Starting ]]; do
                sleep 1
              done
              if [[ $state == NeedsLogin || $state == NeedsMachineAuth || $state == Stopped ]]; then
                ts up "''${prefs[@]}" --timeout=60s \
                  --auth-key=file:${config.sops.secrets."vpn-exit-${country}-auth-key".path}
              fi
              ts set "''${prefs[@]}"
            '';
          };
        }
      );

      fleet.carry = map (country: "var/lib/tailscale-${country}") (lib.attrNames countries);
      preservation.preserveAt."/persist".directories = map (country: {
        directory = "/var/lib/tailscale-${country}";
        mode = "0700";
      }) (lib.attrNames countries);
    };
}
