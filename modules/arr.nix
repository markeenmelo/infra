{ config, ... }:
let
  inherit (config.flake.modules.nixos) nixflix postgresql;
  inherit (config.fleet) domain;
  apps = [
    "sonarr"
    "radarr"
    "prowlarr"
  ];
  indexers = [
    "Knaben"
    "The Pirate Bay"
    "YTS"
    "showRSS"
    "Nyaa.si"
  ];
  # ProtonVPN's NAT-PMP gateway inside the tunnel
  protonGateway = "10.2.0.1";
in
{
  flake.modules.nixos.arr =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      vpn = config.nixflix.vpn.namespace;
      inherit (config.vpnNamespaces.${vpn}) namespaceAddress;
      qbittorrent = config.nixflix.torrentClients.qbittorrent;
      inherit (config.services.qbittorrent) webuiPort;
      secret = name: { _secret = config.sops.secrets."arr-${name}".path; };
      media = dirOf config.nixflix.mediaDir;
    in
    {
      imports = [
        nixflix
        postgresql
      ];
      sops.secrets =
        lib.mapAttrs'
          (name: units: {
            name = "arr-${name}";
            value = {
              sopsFile = ../secrets/hosts/${config.networking.hostName}.yaml;
              key = "arr/${name}";
              restartUnits = map (unit: "${unit}.service") units;
            };
          })
          {
            sonarr-api-key = [
              "sonarr"
              "prowlarr-applications"
            ];
            radarr-api-key = [
              "radarr"
              "prowlarr-applications"
            ];
            prowlarr-api-key = [ "prowlarr" ];
            password = [
              "sonarr-config"
              "radarr-config"
              "prowlarr-config"
            ];
            qbittorrent-password = [
              "sonarr-downloadclients"
              "radarr-downloadclients"
              "qbittorrent-port-forward"
            ];
            qbittorrent-password-hash = [ "qbittorrent" ];
            proton-wireguard = [ vpn ];
          };
      nixflix = lib.mkMerge [
        {
          postgres.enable = true;
          vpn = {
            enable = true;
            wgConfFile = config.sops.secrets.arr-proton-wireguard.path;
            accessibleFrom = [ ];
          };
          torrentClients.qbittorrent = {
            enable = true;
            vpn.enable = true;
            profileDir = "${config.nixflix.stateDir}/qbittorrent";
            password = secret "qbittorrent-password";
            serverConfig = {
              BitTorrent.Session = {
                QueueingSystemEnabled = true;
                IgnoreSlowTorrentsForQueueing = true;
                SlowTorrentsDownloadRate = 2;
                SlowTorrentsUploadRate = 2;
                SlowTorrentsInactivityTimer = 60;
                MaxActiveDownloads = 10;
                MaxActiveTorrents = 20;
                MaxActiveUploads = 10;
                GlobalMaxRatio = 0.5;
                GlobalMaxSeedingMinutes = 30;
                GlobalUPSpeedLimit = 500;
                ReannounceWhenAddressChanged = true;
              };
              Preferences.WebUI = {
                Username = "marcos";
                ServerDomains = "qbittorrent.${domain}";
              };
            };
          };
          prowlarr.config.indexers = map (name: {
            inherit name;
            enable = true;
            "torrentBaseSettings.appMinimumSeeders" = 5;
          }) indexers;
        }
        (lib.genAttrs apps (name: {
          enable = true;
          vpn.enable = true;
          config = {
            apiKey = secret "${name}-api-key";
            hostConfig = {
              username = "marcos";
              password = secret "password";
            };
          };
        }))
      ];
      # the uid that owns qbittorrent's state, allocated by the old generation; nixflix pins 70 with mkForce
      users.users.qbittorrent.uid = lib.mkOverride 49 988;
      fleet.web.apps = lib.mkMerge [
        (lib.genAttrs apps (name: {
          inherit (config.nixflix.${name}.config.hostConfig) port;
          address = namespaceAddress;
          tailnetOnly = true;
        }))
        {
          qbittorrent = {
            port = webuiPort;
            address = namespaceAddress;
            tailnetOnly = true;
          };
        }
      ];
      networking.nftables.tables.arr-vpn = {
        family = "inet";
        content = ''
          chain forward {
            type filter hook forward priority -200; policy accept;
            oifname "${vpn}-br" counter drop
            iifname "${vpn}-br" counter drop
          }
          chain output {
            type filter hook output priority -150; policy accept;
            ct state new oifname "${vpn}-br" meta skuid != { ${
              lib.concatMapStringsSep ", " toString (
                [ 0 ] ++ lib.optional config.services.caddy.enable config.users.users.caddy.uid
              )
            } } reject
          }
        '';
      };
      systemd.services = lib.mkMerge [
        (lib.genAttrs (apps ++ [ "qbittorrent" ]) (_: {
          unitConfig.RequiresMountsFor = [
            config.nixflix.stateDir
            media
          ];
        }))
        {
          qbittorrent.serviceConfig = {
            LoadCredential = [
              "webui-password-hash:${config.sops.secrets.arr-qbittorrent-password-hash.path}"
            ];
            ExecStartPre = lib.mkAfter [
              (lib.getExe (
                pkgs.writeShellApplication {
                  name = "qbittorrent-webui-password";
                  runtimeInputs = [ pkgs.gawk ];
                  text = ''
                    umask 077
                    conf=${qbittorrent.profileDir}/qBittorrent/config/qBittorrent.conf
                    HASH=$(< "$CREDENTIALS_DIRECTORY/webui-password-hash") awk '
                      /^WebUI\\Password_PBKDF2=/ { next }
                      { print }
                      /^\[Preferences\]$/ { print "WebUI\\Password_PBKDF2=" ENVIRON["HASH"] }
                    ' "$conf" > "$conf.new"
                    mv "$conf.new" "$conf"
                  '';
                }
              ))
            ];
          };
          qbittorrent-port-forward = {
            description = "Keep ProtonVPN's forwarded port open for qBittorrent";
            after = [
              "${vpn}.service"
              "qbittorrent.service"
            ];
            requires = [
              "${vpn}.service"
              "qbittorrent.service"
            ];
            wantedBy = [ "multi-user.target" ];
            path = [
              pkgs.curl
              pkgs.iproute2
              pkgs.iptables
              pkgs.libnatpmp
              pkgs.gawk
            ];
            enableStrictShellChecks = true;
            serviceConfig = {
              Restart = "on-failure";
              RestartSec = "5s";
              RuntimeDirectory = "qbittorrent-port-forward";
              LoadCredential = [ "password:${config.sops.secrets.arr-qbittorrent-password.path}" ];
            };
            script = ''
              api=http://${namespaceAddress}:${toString webuiPort}/api/v2
              cookies=$RUNTIME_DIRECTORY/cookies
              current=""
              fw() { ip netns exec ${vpn} iptables "$@"; }
              fw -N qbittorrent-port 2>/dev/null || true
              fw -C INPUT -j qbittorrent-port 2>/dev/null || fw -I INPUT -j qbittorrent-port
              open_port() {
                fw -F qbittorrent-port
                for proto in tcp udp; do
                  fw -A qbittorrent-port -i ${vpn}0 -p "$proto" --dport "$1" -j ACCEPT
                done
              }
              set_port() {
                curl -fsS -c "$cookies" --data-urlencode username=marcos \
                  --data-urlencode "password@$CREDENTIALS_DIRECTORY/password" "$api/auth/login" > /dev/null
                curl -fsS -b "$cookies" --data "json={\"listen_port\":$1,\"random_port\":false}" "$api/app/setPreferences"
                curl -fsS -b "$cookies" --data hashes=all "$api/torrents/reannounce"
              }
              while true; do
                port=$(ip netns exec ${vpn} natpmpc -a 1 0 udp 60 -g ${protonGateway} | awk '/Mapped public port/ { print $4 }')
                ip netns exec ${vpn} natpmpc -a 1 0 tcp 60 -g ${protonGateway} > /dev/null
                if [ -z "$port" ]; then
                  echo "No port from ${protonGateway}; is the tunnel up?"
                  sleep 5
                  continue
                fi
                if [ "$port" != "$current" ]; then
                  echo "Forwarded port $current -> $port"
                  open_port "$port" && set_port "$port" && current=$port
                fi
                sleep 45
              done
            '';
          };
        }
      ];
    };
}
