{ config, lib, ... }:
let
  inherit (config.fleet) hosts;
  names = import ./_game-cache-names.nix;
in
{
  flake.modules.nixos.lancache =
    { config, pkgs, ... }:
    let
      inherit (hosts.${config.networking.hostName}) lan;
      cache = "/var/cache/lancache";
      httpPort = 3180;
      tlsPort = 3443;
      resolver = "resolver 1.1.1.1 9.9.9.9 ipv6=off;";
      wild = map (lib.removePrefix "*") (lib.filter (lib.hasPrefix "*.") names);
      exact = lib.filter (name: !lib.hasPrefix "*." name && !lib.elem ".${name}" wild) names;
      allowed = value: lib.concatMapStrings (name: "  ${name} ${value};\n") (wild ++ exact);
    in
    {
      systemd.network.networks."10-uplink".addresses = [
        {
          Address = "${lan.gameCache}/24";
          PreferredLifetime = 0;
        }
      ];
      networking.nftables.tables.lancache = {
        family = "ip";
        content = ''
          chain prerouting {
            type nat hook prerouting priority dstnat; policy accept;
            ip daddr ${lan.gameCache} tcp dport 80 dnat to ${lan.gameCache}:${toString httpPort}
            ip daddr ${lan.gameCache} tcp dport 443 dnat to ${lan.gameCache}:${toString tlsPort}
          }
        '';
      };
      services.dnsmasq.settings.address = map (domain: "/${domain}/${lan.gameCache}") (
        lib.unique (map (lib.removePrefix "*.") names)
      );
      networking.firewall.extraInputRules = ''
        ip daddr ${lan.gameCache} tcp dport { ${toString httpPort}, ${toString tlsPort} } ct original proto-dst { 80, 443 } accept
      '';
      services.nginx = {
        enable = true;
        package = pkgs.nginxStable.override { withSlice = true; };
        appendHttpConfig = ''
          proxy_cache_path ${cache}/data levels=2:2 keys_zone=lancache:500m inactive=3650d max_size=950g use_temp_path=off;
          map $host $lancache_allowed {
            hostnames;
            default 0;
          ${allowed "1"}}
          map "$http_user_agent£££$http_host" $lancache_id {
            default $http_host;
            "~Valve/Steam HTTP Client 1\.0£££.*" steam;
          }
        '';
        virtualHosts.lancache = {
          serverName = "_";
          listen = [
            {
              addr = lan.gameCache;
              port = httpPort;
            }
          ];
          locations."/".extraConfig = ''
            if ($lancache_allowed = 0) {
              return 403;
            }
            ${resolver}
            slice 1m;
            proxy_cache lancache;
            proxy_cache_key $lancache_id$uri$slice_range;
            proxy_set_header Range $slice_range;
            proxy_cache_valid 200 206 3650d;
            proxy_cache_lock on;
            proxy_cache_lock_age 2m;
            proxy_cache_lock_timeout 1h;
            proxy_cache_use_stale error timeout invalid_header updating http_500 http_502 http_503 http_504;
            proxy_ignore_headers Expires Cache-Control;
            proxy_hide_header ETag;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header Connection "";
            proxy_pass http://$host$request_uri;
            add_header X-LanCache-Status $upstream_cache_status;
          '';
        };
        streamConfig = ''
          map $ssl_preread_server_name $lancache_tls {
            hostnames;
            default 127.0.0.1:9;
          ${allowed "$ssl_preread_server_name:443"}}
          server {
            listen ${lan.gameCache}:${toString tlsPort};
            ${resolver}
            ssl_preread on;
            proxy_pass $lancache_tls;
          }
        '';
      };
      systemd.services.nginx = {
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        unitConfig.RequiresMountsFor = cache;
        serviceConfig = {
          ReadWritePaths = [ cache ];
          ExecStartPre = [
            "+${pkgs.coreutils}/bin/install -d -o nginx -g nginx -m 0750 ${cache}/data"
            "+${pkgs.writeShellScript "lancache-address" ''
              for _ in $(${pkgs.coreutils}/bin/seq 100); do
                ${pkgs.iproute2}/bin/ip -4 -o addr show to ${lan.gameCache} | ${pkgs.gnugrep}/bin/grep -q . && exit 0
                ${pkgs.coreutils}/bin/sleep 0.2
              done
              echo "${lan.gameCache} never came up" >&2
              exit 1
            ''}"
          ];
        };
      };
    };
}
