{ config, lib, ... }:
let
  inherit (config.flake.modules.nixos) caddy;
  inherit (config.fleet) domain;
  declared = config.flake.nixosConfigurations.bastion.config.fleet.web.apps;
  bastion = config.fleet.hosts.bastion.tailnetAddress;
  served = lib.filterAttrs (_: app: app.public) declared;
in
{
  flake.modules.nixos.edge =
    {
      config,
      lib,
      pkgs,
      ...
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
        name:
        { port, denied, ... }:
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
        '') denied
        + ''
            reverse_proxy ${bastion}:${toString port}
          }
        '';
    in
    {
      imports = [ caddy ];
      services.caddy = {
        globalConfig = ''
          servers {
            protocols h1 h2
          }
        '';
        logFormat = ''
          level ERROR
          format filter {
            wrap console
            ${logFilter}
          }
        '';
        virtualHosts."*.${domain}" = {
          logFormat = ''
            output file ${config.services.caddy.logDir}/access.log {
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
              log_append @abroad edge_denied abroad
              abort @abroad
              log_append @hosting edge_denied hosting
              abort @hosting
              log_append @crawler edge_denied crawler
              abort @crawler
              respond /robots.txt <<TXT
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
      };
      fleet.probes = lib.mapAttrs (name: _: "https://${name}.${domain}") served;
      networking.hosts."127.0.0.1" = map (name: "${name}.${domain}") (lib.attrNames served);
      systemd.services.caddy.serviceConfig.LogsDirectoryMode = "0750";
      networking.firewall.allowedTCPPorts = [
        80
        443
      ];
      preservation.preserveAt."/persist".directories = [
        {
          directory = config.services.caddy.logDir;
          user = config.services.caddy.user;
          group = config.services.caddy.group;
          mode = "0750";
        }
      ];
    };
}
