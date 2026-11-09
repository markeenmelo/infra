{ config, ... }:
let
  inherit (config.flake.modules.nixos) nixflix;
  # the third octet of each tunnel's namespace subnet
  countries = {
    ca = 1;
    us = 2;
    br = 3;
  };
in
{
  flake.modules.nixos.proton-exit =
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
      imports = [ nixflix ];

      sops.secrets = perCountry (
        country: _:
        lib.genAttrs [ "proton-exit-${country}" "proton-exit-${country}-auth-key" ] (name: {
          sopsFile = ../secrets/hosts/${config.networking.hostName}.yaml;
          key = "proton-exit/${lib.removePrefix "proton-exit-" name}";
          restartUnits = [
            "pv${country}.service"
            "tailscaled-${country}.service"
          ];
        })
      );

      vpnNamespaces = perCountry (
        country: subnet: {
          "pv${country}" = {
            enable = true;
            wireguardConfigFile = config.sops.secrets."proton-exit-${country}".path;
            namespaceAddress = "10.200.${toString subnet}.1";
            bridgeAddress = "10.200.${toString subnet}.5";
          };
        }
      );

      # shortcut: tailscaled's own control, DERP and peer traffic also leaves through Proton, so peers mostly relay over DERP; route its fwmark over the bridge if throughput matters
      systemd.services = perCountry (
        country: _: {
          "pv${country}" = {
            upholds = [ "tailscaled-${country}.service" ];
            startLimitIntervalSec = 3600;
            startLimitBurst = 120;
            serviceConfig = {
              Restart = "on-failure";
              RestartSec = 30;
            };
          };
          "tailscaled-${country}" = {
            description = "Tailscale exit node through Proton VPN (${country})";
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
            serviceConfig.Type = "oneshot";
            script = ''
              ts() { ${tailscale} --socket=${socket country} "$@"; }
              if [ "$(ts status --json --peers=false | jq -r .BackendState)" = NeedsLogin ]; then
                ts up --hostname=proton-${country} --advertise-exit-node \
                  --auth-key=file:${config.sops.secrets."proton-exit-${country}-auth-key".path}
              fi
              ts set \
                --hostname=proton-${country} \
                --advertise-exit-node=true \
                --accept-dns=false \
                --accept-routes=false \
                --ssh=false \
                --webclient=false \
                --auto-update=false
            '';
          };
          "pv${country}-watch" = {
            description = "Restart the Proton tunnel (${country}) when its handshake is stale";
            unitConfig.ConditionPathExists = "/run/netns/pv${country}";
            path = [
              pkgs.iproute2
              pkgs.wireguard-tools
            ];
            enableStrictShellChecks = true;
            serviceConfig.Type = "oneshot";
            script = ''
              latest=$(ip netns exec pv${country} wg show pv${country}0 latest-handshakes | cut -f2 | sort -n | tail -n1)
              if (( $(date +%s) - ''${latest:-0} >= 300 )); then
                echo "last Proton handshake ''${latest:-never}, restarting" >&2
                systemctl restart pv${country}.service
              fi
            '';
          };
        }
      );

      systemd.timers = perCountry (
        country: _: {
          "pv${country}-watch" = {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "5min";
              OnUnitActiveSec = "2min";
            };
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
