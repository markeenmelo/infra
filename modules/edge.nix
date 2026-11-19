{ config, lib, ... }:
let
  inherit (config.flake.modules.nixos) caddy;
  inherit (config.fleet) domain;
  declared = config.flake.nixosConfigurations.bastion.config.fleet.web.apps;
  bastion = config.fleet.hosts.bastion.tailnetAddress;
  edge = config.fleet.hosts.edge.tailnetAddress;
  port = config.fleet.publicPort;
  served = lib.filterAttrs (_: app: app.public) declared;
  hostnames = map (name: "${name}.${domain}") (lib.attrNames served);
  policy =
    {
      lib,
      pkgs,
      logDir,
    }:
    let
      countries = [ "CA" ];
      hosting = {
        amazon = [
          16509
          14618
        ];
        google = [
          15169
          396982
        ];
        microsoft = [ 8075 ];
        digitalocean = [ 14061 ];
        ovh = [ 16276 ];
        linode = [ 63949 ];
        vultr = [ 20473 ];
        hetzner = [ 24940 ];
        oracle = [ 31898 ];
        alibaba = [
          45102
          37963
        ];
        tencent = [
          132203
          45090
        ];
        contabo = [ 51167 ];
        scaleway = [ 12876 ];
        m247 = [ 9009 ];
        leaseweb = [ 60781 ];
        datacamp = [ 60068 ];
      };
      crawlers = [
        "GPTBot"
        "ChatGPT-User"
        "OAI-SearchBot"
        "ClaudeBot"
        "Claude-Web"
        "anthropic-ai"
        "CCBot"
        "Bytespider"
        "Amazonbot"
        "PerplexityBot"
        "Applebot"
        "meta-externalagent"
        "FacebookBot"
        "Diffbot"
        "ImagesiftBot"
        "Omgilibot"
        "cohere-ai"
        "YouBot"
        "Googlebot"
        "bingbot"
        "YandexBot"
        "Baiduspider"
        "DuckDuckBot"
        "AhrefsBot"
        "SemrushBot"
        "MJ12bot"
        "DotBot"
        "PetalBot"
        "DataForSeoBot"
        "BLEXBot"
        "Scrapy"
        "HeadlessChrome"
        "PhantomJS"
      ];
      logFilter = ''
        fields {
          request>headers>Authorization delete
          request>headers>Proxy-Authorization delete
          request>headers>Cookie delete
          resp_headers>Set-Cookie delete
          resp_headers>Location delete
          request>headers>X-Emby-Token delete
          request>headers>X-Mediabrowser-Token delete
          request>headers>X-Emby-Authorization delete
          request>headers>X-Api-Key delete
          request>headers>X-Immich-User-Token delete
          request>headers>X-Immich-Session-Token delete
          request>headers>X-Immich-Share-Key delete
          request>headers>Public-Token delete
          request>headers>Referer delete
          request>uri multi_regexp {
            regexp "[?].*" ""
            regexp "^/s/[^/]+" "/s/REDACTED"
            regexp "^/share/[^/]+" "/share/REDACTED"
            regexp "^/files/link/public/[^/]+" "/files/link/public/REDACTED"
            regexp "^(/remote.php)?/dav/public-files/[^/]+" "/dav/public-files/REDACTED"
            regexp "^/data/[^/]+" "/data/REDACTED"
            regexp "^/ocs/v[12][.]php/apps/files_sharing/api/v1/tokeninfo/(un)?protected/[^/]+" "/ocs/apps/files_sharing/api/v1/tokeninfo/REDACTED"
          }
        }
      '';
      site =
        name: app:
        ''
          @${name} host ${name}.${domain}
          handle @${name} {
        ''
        + lib.concatImapStrings (i: matcher: ''
          @${name}-denied-${toString i} {
            ${matcher}
          }
          log_append @${name}-denied-${toString i} edge_denied path
          respond @${name}-denied-${toString i} 404
        '') app.denied
        + ''
            reverse_proxy ${app.address}:${toString app.port}
          }
        '';
    in
    {
      errorLog = ''
        level ERROR
        format filter {
          wrap console
          ${logFilter}
        }
      '';
      accessLog = ''
        output file ${logDir}/access.log {
          mode 0640
        }
        format filter {
          wrap json
          ${logFilter}
        }
      '';
      extraConfig = ''
        import porkbun
        header {
          Strict-Transport-Security "max-age=63072000; includeSubDomains"
          X-Content-Type-Options nosniff
          Referrer-Policy no-referrer
          X-Robots-Tag "noindex, nofollow, noarchive, nosnippet, noimageindex"
          ?X-Frame-Options SAMEORIGIN
          ?Permissions-Policy "camera=(), microphone=(), geolocation=(), payment=(), usb=(), browsing-topics=()"
          ?Cross-Origin-Opener-Policy same-origin-allow-popups
          -Server
          -Via
          -X-Powered-By
        }
        @crawler header_regexp User-Agent "(?i)(${lib.concatStringsSep "|" crawlers})"
        @robots {
          path /robots.txt
          host ${lib.concatStringsSep " " hostnames}
        }
        @abroad {
          not remote_ip 127.0.0.0/8 ::1
          not {
            maxmind_geolocation {
              db_path ${pkgs.dbip-country-lite.mmdb}
              allow_countries ${lib.concatStringsSep " " countries}
            }
          }
        }
        @hosting {
          not remote_ip 127.0.0.0/8 ::1
          not {
            maxmind_geolocation {
              db_path ${pkgs.dbip-asn-lite.mmdb}
              deny_asn ${lib.concatMapStringsSep " " toString (lib.concatLists (lib.attrValues hosting))}
            }
          }
        }
        import identity
        route {
          log_append @abroad <edge_denied abroad
          abort @abroad
          log_append @hosting <edge_denied hosting
          abort @hosting
          log_append @crawler <edge_denied crawler
          abort @crawler
          respond @robots <<TXT
            User-agent: *
            Disallow: /
            TXT 200
          rate_limit {
            zone address {
              key {remote_host}
              events 3000
              window 1m
            }
          }
          ${lib.concatStrings (lib.mapAttrsToList site served)}
          handle {
            abort
          }
        }
      '';
    };
in
{
  options.fleet.publicPort = lib.mkOption {
    type = lib.types.port;
    description = "Port on bastion's tailnet address where its Caddy terminates TLS for the connections the edge passes through; the `tofu` app hands it to `opentofu/tailscale` as `fleet_public_port`.";
  };
  config.fleet.publicPort = 8443;

  config.flake.modules.nixos.public-proxy =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      rules = policy {
        inherit lib pkgs;
        inherit (config.services.caddy) logDir;
      };
    in
    {
      imports = [ caddy ];
      services.caddy = {
        globalConfig = ''
          servers :${toString port} {
            listener_wrappers {
              proxy_protocol {
                allow ${edge}/32
                fallback_policy reject
                timeout 5s
              }
              tls
            }
            protocols h1 h2
          }
        '';
        logFormat = rules.errorLog;
        virtualHosts.public = {
          hostName = "*.${domain}:${toString port}";
          logFormat = rules.accessLog;
          inherit (rules) extraConfig;
        };
      };
      systemd.services.caddy.serviceConfig.LogsDirectoryMode = "0750";
      preservation.preserveAt."/persist".directories = [
        {
          directory = config.services.caddy.logDir;
          user = config.services.caddy.user;
          group = config.services.caddy.group;
          mode = "0750";
        }
      ];
      networking.firewall.extraInputRules = ''
        iifname "${config.services.tailscale.interfaceName}" ip saddr ${edge} tcp dport ${toString port} accept
      '';
    };

  config.flake.modules.nixos.passthrough = {
    services.nginx = {
      enable = true;
      appendConfig = "worker_rlimit_nofile 8192;";
      eventsConfig = "worker_connections 4096;";
      streamConfig = ''
        limit_conn_zone $binary_remote_addr zone=source:1m;
        server {
          listen 443;
          proxy_pass ${bastion}:${toString port};
          proxy_protocol on;
          proxy_connect_timeout 5s;
          limit_conn source 64;
        }
      '';
      virtualHosts.redirect = {
        default = true;
        extraConfig = "access_log off;";
        locations."/".return = "308 https://$host$request_uri";
      };
    };
    fleet.probes = lib.mapAttrs (name: _: "https://${name}.${domain}") served;
    networking.hosts."127.0.0.1" = hostnames;
    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
  };
}
