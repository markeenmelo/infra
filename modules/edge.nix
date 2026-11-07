{ config, lib, ... }:
let
  inherit (config.flake.modules.nixos) caddy;
  inherit (config.fleet) domain;
  declared = config.flake.nixosConfigurations.bastion.config.fleet.web.apps;
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
      # shortcut: bastion's tailnet address is a literal, read it from fleet facts when a second host needs it
      bastion = "100.105.158.109";
      countries = [ "CA" ];
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
            header @abroad Edge-Denied 1
            respond @abroad 403
        ''
        + lib.concatImapStrings (i: matcher: ''
          @${name}-denied-${toString i} {
            ${matcher}
          }
          header @${name}-denied-${toString i} Edge-Denied 1
          respond @${name}-denied-${toString i} 403
        '') denied
        + ''
            reverse_proxy ${bastion}:${toString port}
          }
        '';
    in
    {
      imports = [ caddy ];
      services.caddy = {
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
              Strict-Transport-Security "max-age=31536000"
              X-Content-Type-Options nosniff
              Referrer-Policy no-referrer
              X-Robots-Tag "noindex, nofollow, noarchive, nosnippet, noimageindex"
              -Server
            }
            @abroad {
              not {
                maxmind_geolocation {
                  db_path ${pkgs.dbip-country-lite.mmdb}
                  allow_countries ${lib.concatStringsSep " " countries}
                }
              }
            }
            import identity
            ${lib.concatStrings (lib.mapAttrsToList site served)}
            handle {
              abort
            }
          '';
        };
      };
      systemd.services.caddy.serviceConfig.LogsDirectoryMode = "0750";
      networking.firewall = {
        allowedTCPPorts = [
          80
          443
        ];
        allowedUDPPorts = [ 443 ];
      };
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
