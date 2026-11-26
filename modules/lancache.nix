{ config, ... }:
let
  inherit (config.fleet.hosts.bastion) lan;
in
{
  flake.modules.nixos.lancache =
    { pkgs, ... }:
    let
      cache = "/var/cache/lancache";
      httpPort = 3180;
      tlsPort = 3443;
      resolver = "resolver 1.1.1.1 9.9.9.9 ipv6=off;";
    in
    {
      networking.nftables.tables.lancache = {
        family = "ip";
        content = ''
          chain prerouting {
            type nat hook prerouting priority dstnat; policy accept;
            ip daddr ${lan.gameCache} tcp dport 80 redirect to :${toString httpPort}
            ip daddr ${lan.gameCache} tcp dport 443 redirect to :${toString tlsPort}
          }
        '';
      };
      networking.firewall.allowedTCPPorts = [
        httpPort
        tlsPort
      ];
      services.nginx = {
        enable = true;
        package = pkgs.nginxStable.override { withSlice = true; };
        appendHttpConfig = ''
          proxy_cache_path ${cache}/data levels=2:2 keys_zone=lancache:500m inactive=3650d max_size=950g use_temp_path=off;
          map "$http_user_agent£££$http_host" $lancache_id {
            default $http_host;
            "~Valve/Steam HTTP Client 1\.0£££.*" steam;
          }
        '';
        virtualHosts.lancache = {
          serverName = "_";
          listen = [
            {
              addr = "0.0.0.0";
              port = httpPort;
            }
          ];
          locations."/".extraConfig = ''
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
          server {
            listen ${toString tlsPort};
            ${resolver}
            ssl_preread on;
            proxy_pass $ssl_preread_server_name:443;
          }
        '';
      };
      systemd = {
        services.nginx.unitConfig.RequiresMountsFor = cache;
        tmpfiles.rules = [ "d ${cache}/data 0750 nginx nginx -" ];
      };
    };
}
