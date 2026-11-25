{ inputs, ... }:
{
  flake.modules.nixos.vpn-watch = {
    key = "fleet-vpn-watch";
    imports = [
      inputs.nixflix.inputs.vpn-confinement.nixosModules.default
      (
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          confined =
            namespace:
            lib.attrNames (
              lib.filterAttrs (
                _: unit:
                unit.enable
                && unit.vpnConfinement.enable
                && unit.vpnConfinement.vpnNamespace == namespace
                && lib.elem "multi-user.target" unit.wantedBy
                && (unit.serviceConfig.Type or "simple") != "oneshot"
              ) config.systemd.services
            );
          perNamespace =
            f:
            lib.mkMerge (
              map f (lib.attrNames (lib.filterAttrs (_: namespace: namespace.enable) config.vpnNamespaces))
            );
          pia =
            namespace: region:
            pkgs.writeShellApplication {
              name = "${namespace}-pia";
              runtimeInputs = [
                pkgs.curl
                pkgs.jq
                pkgs.wireguard-tools
              ];
              text = ''
                umask 077
                cd "$RUNTIME_DIRECTORY"
                get() { curl -fsS --retry 3 --max-time 30 "$@"; }
                list=$(get https://serverlist.piaservers.net/vpninfo/servers/v6)
                server=$(head -n1 <<< "$list" |
                  jq -ce --arg region ${region} --argjson pick "$RANDOM" '.regions[] | select(.id == $region) | .servers.wg | .[$pick % length]')
                cn=$(jq -r .cn <<< "$server")
                get --form "username=<$CREDENTIALS_DIRECTORY/username" --form "password=<$CREDENTIALS_DIRECTORY/password" \
                  https://www.privateinternetaccess.com/api/client/v2/token | jq -je .token > token
                wg genkey > key
                reply=$(get -G --connect-to "$cn::$(jq -r .ip <<< "$server"):" --cacert ${./pia.crt} \
                  --data-urlencode pt@token --data-urlencode "pubkey=$(wg pubkey < key)" "https://$cn:1337/addKey")
                jq -e '.status == "OK"' <<< "$reply" > /dev/null
                jq -n --arg cn "$cn" --argjson reply "$reply" '{ $cn, gateway: $reply.server_vip }' > server.json
                jq -r --rawfile key key '[
                  "[Interface]",
                  "PrivateKey = \($key | rtrimstr("\n"))",
                  "Address = \(.peer_ip)",
                  "DNS = \(.dns_servers[0])",
                  "[Peer]",
                  "PublicKey = \(.server_key)",
                  "Endpoint = \(.server_ip):\(.server_port)",
                  "AllowedIPs = 0.0.0.0/0",
                  "PersistentKeepalive = 25"
                ] | join("\n")' <<< "$reply" > wg.conf
              '';
            };
        in
        {
          options = {
            fleet.piaCredentials = lib.genAttrs [ "username" "password" ] (
              field:
              lib.mkOption {
                type = lib.types.str;
                description = "File holding the Private Internet Access ${field} every PIA tunnel of the host signs in with.";
              }
            );
            vpnNamespaces = lib.mkOption {
              type = lib.types.attrsOf (
                lib.types.submodule (
                  { config, name, ... }:
                  {
                    options.piaRegion = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                      description = "Private Internet Access region id from its server list; each start of the tunnel registers a new key with one of the region's WireGuard servers and writes the config.";
                    };
                    config.wireguardConfigFile = lib.mkIf (config.piaRegion != null) "/run/pia-${name}/wg.conf";
                  }
                )
              );
            };
          };

          config = {
            systemd.services = perNamespace (
              namespace:
              let
                inherit (config.vpnNamespaces.${namespace}) piaRegion;
              in
              {
                ${namespace} = {
                  wants = map (name: "${name}.service") (confined namespace);
                  startLimitIntervalSec = 3600;
                  startLimitBurst = 120;
                  serviceConfig = lib.mkMerge [
                    {
                      Restart = "on-failure";
                      RestartSec = 30;
                    }
                    (lib.mkIf (piaRegion != null) {
                      ExecStartPre = lib.getExe (pia namespace piaRegion);
                      RestartSteps = 6;
                      RestartMaxDelaySec = "30min";
                      RuntimeDirectory = "pia-${namespace}";
                      RuntimeDirectoryMode = "0700";
                      LoadCredential = lib.mapAttrsToList (field: file: "${field}:${file}") config.fleet.piaCredentials;
                    })
                  ];
                };
                "${namespace}-watch" = {
                  description = "Restart the ${namespace} tunnel when its handshake is stale";
                  path = [
                    pkgs.iproute2
                    pkgs.iputils
                    pkgs.wireguard-tools
                  ];
                  enableStrictShellChecks = true;
                  serviceConfig.Type = "oneshot";
                  script = ''
                    [ -e /run/netns/${namespace} ] || exit 0
                    since=$(systemctl show -P ActiveEnterTimestampMonotonic ${namespace}.service)
                    (( $(cut -d. -f1 /proc/uptime) - since / 1000000 < 300 )) && exit 0
                    stale() {
                      latest=$(ip netns exec ${namespace} wg show ${namespace}0 latest-handshakes | cut -f2 | sort -n | tail -n1)
                      (( $(date +%s) - ''${latest:-0} >= 300 ))
                    }
                    stale || exit 0
                    ip netns exec ${namespace} ping -c 3 -W 2 1.1.1.1 > /dev/null || true
                    if stale; then
                      echo "last handshake ''${latest:-never}, restarting" >&2
                      systemctl restart ${namespace}.service
                    fi
                  '';
                };
              }
            );
            systemd.timers = perNamespace (namespace: {
              "${namespace}-watch" = {
                wantedBy = [ "timers.target" ];
                timerConfig = {
                  OnActiveSec = "5min";
                  OnUnitActiveSec = "2min";
                };
              };
            });
          };
        }
      )
    ];
  };
}
