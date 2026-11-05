{ config, ... }:
let
  inherit (config.flake.modules.nixos) caddy;
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
      domain = "marcosmelo.dev";
      # shortcut: bastion's tailnet address and the app ports are literals, read them from fleet facts when bastion lands
      bastion = "100.105.158.109";
      countries = [ "CA" ];
      jellyfin = "(?i)^/(emby/|mediabrowser/)?";
      apps = {
        auth.port = 9091;
        cloud = {
          port = 8081;
          denied = [
            "path /settings/admin* /settings/users* /settings/apps* /index.php/settings/admin* /index.php/settings/users* /index.php/settings/apps* /ocs/v1.php/cloud/groups* /ocs/v2.php/cloud/groups* /ocs/v1.php/cloud/apps* /ocs/v2.php/cloud/apps* /ocs/v1.php/cloud/users/*/enable /ocs/v2.php/cloud/users/*/enable /ocs/v1.php/cloud/users/*/disable /ocs/v2.php/cloud/users/*/disable /ocs/v1.php/cloud/users/*/groups* /ocs/v2.php/cloud/users/*/groups* /ocs/v1.php/cloud/users/*/subadmins* /ocs/v2.php/cloud/users/*/subadmins* /ocs/v1.php/apps/provisioning_api/api/v1/config/apps* /ocs/v2.php/apps/provisioning_api/api/v1/config/apps*"
            "method POST DELETE\n  path /ocs/v1.php/cloud/users /ocs/v2.php/cloud/users /ocs/v1.php/cloud/users/* /ocs/v2.php/cloud/users/*"
          ];
        };
        home = {
          port = 8123;
          denied = [ "path /api/onboarding* /onboarding.html*" ];
        };
        photos = {
          port = 2283;
          denied = [
            "path /api/admin/* /api/auth/admin-sign-up /api/system-config* /api/system-metadata* /api/jobs* /api/queues* /api/libraries*"
          ];
        };
        jellyfin.port = 8096;
        jellyfin.denied = [
          "path_regexp ${jellyfin}(Backup|Devices|Plugins|Packages|Repositories|Environment|ScheduledTasks|Startup|Auth/Keys|Library/(VirtualFolders|Refresh)|LiveTv/(TunerHosts|ListingProviders)|Items/(RemoteSearch/Apply|[^/]+/(Refresh|ContentType|RemoteImages/Download))|Videos/(MergeVersions|[^/]+/AlternateSources)|Library/(Media|Movies|Series)/(Added|Updated)|System/(ActivityLog|Configuration|Restart|Shutdown|Logs)|Users/(New|Password|Policy|[^/]+/(Policy|Password))|sso/((OID|SAML)/((Add|Del)/|(Get|States)/?$)|Unregister/))"
          "method DELETE\n  path_regexp ${jellyfin}Users/[^/]+/?$"
          "method DELETE POST\n  path_regexp ${jellyfin}Items(/[^/]+(/Images(/.*)?)?)?/?$"
        ];
      };
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
          request>headers>Referer delete
          request>uri multi_regexp {
            regexp "[?].*" ""
            regexp "^/api/webhook/[^/]+" "/api/webhook/REDACTED"
            regexp "^/index.php/lostpassword/reset/form/[^/]+" "/index.php/lostpassword/reset/form/REDACTED"
            regexp "^/lostpassword/reset/form/[^/]+" "/lostpassword/reset/form/REDACTED"
            regexp "^/index.php/s/[^/]+" "/index.php/s/REDACTED"
            regexp "^/s/[^/]+" "/s/REDACTED"
            regexp "^/share/[^/]+" "/share/REDACTED"
            regexp "^/public.php/dav/files/[^/]+" "/public.php/dav/files/REDACTED"
            regexp "^/index.php/apps/files_sharing/publicpreview/[^/]+" "/index.php/apps/files_sharing/publicpreview/REDACTED"
            regexp "^/apps/files_sharing/publicpreview/[^/]+" "/apps/files_sharing/publicpreview/REDACTED"
          }
        }
      '';
      site =
        name:
        {
          port,
          denied ? [ ],
        }:
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
            tls {
              dns porkbun {
                api_key {env.PORKBUN_API_KEY}
                api_secret_key {env.PORKBUN_SECRET_KEY}
              }
            }
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
            ${lib.concatStrings (lib.mapAttrsToList site apps)}
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
