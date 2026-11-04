{ config, lib, ... }:
{
  flake.checks = lib.foldlAttrs (
    acc: name: host:
    let
      nixos = config.flake.nixosConfigurations.${name};
      inherit (nixos.config.services) caddy;
    in
    if !caddy.enable then
      acc
    else
      lib.recursiveUpdate acc {
        ${host.system}."caddyfile-${name}" = nixos.pkgs.runCommand "caddyfile-${name}" { } ''
          sed "s|${caddy.logDir}|$TMPDIR|g" ${caddy.configFile} > Caddyfile
          HOME=$TMPDIR XDG_DATA_HOME=$TMPDIR XDG_CONFIG_HOME=$TMPDIR \
            ${caddy.package}/bin/caddy validate --config Caddyfile --adapter caddyfile
          touch $out
        '';
      }
  ) { } config.fleet.hosts;

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
          denied = [ "path /settings/admin* /index.php/settings/admin*" ];
        };
        home = {
          port = 8123;
          denied = [ "path /api/onboarding* /onboarding.html*" ];
        };
        photos = {
          port = 2283;
          denied = [ "path /api/admin/* /api/system-config*" ];
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
          resp_headers>Location regexp "[?].*" ""
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
            respond @abroad 403
        ''
        + lib.concatImapStrings (i: matcher: ''
          @${name}-denied-${toString i} {
            ${matcher}
          }
          respond @${name}-denied-${toString i} 403
        '') denied
        + ''
            reverse_proxy ${bastion}:${toString port}
          }
        '';
    in
    {
      sops = {
        secrets = lib.genAttrs [ "PORKBUN_API_KEY" "PORKBUN_SECRET_KEY" ] (key: {
          sopsFile = ../secrets/porkbun/api.yaml;
        });
        templates.caddy-env = {
          content = ''
            PORKBUN_API_KEY=${config.sops.placeholder.PORKBUN_API_KEY}
            PORKBUN_SECRET_KEY=${config.sops.placeholder.PORKBUN_SECRET_KEY}
          '';
          restartUnits = [ "caddy.service" ];
        };
      };
      services.caddy = {
        enable = true;
        package = pkgs.caddy.withPlugins {
          plugins = [
            "github.com/caddy-dns/porkbun@v0.3.1"
            "github.com/porech/caddy-maxmind-geolocation@v1.0.3"
          ];
          hash = "sha256-urSgwaKHIncei86b1G8SM3iViwTei98aX+XysbZ/2UE=";
        };
        environmentFile = config.sops.templates.caddy-env.path;
        globalConfig = "grace_period 10s";
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
            request_header -Remote-User
            request_header -Remote-Groups
            request_header -Remote-Email
            request_header -Remote-Name
            request_header -X-Forwarded-User
            request_header -X-Forwarded-Groups
            request_header -X-Forwarded-Email
            request_header -X-Forwarded-Preferred-Username
            request_header -X-Forwarded-Access-Token
            ${lib.concatStrings (lib.mapAttrsToList site apps)}
            handle {
              abort
            }
          '';
        };
      };
      systemd.services.caddy = {
        serviceConfig = {
          StateDirectoryMode = "0700";
          LogsDirectoryMode = "0750";
        };
      };
      networking.firewall = {
        allowedTCPPorts = [
          80
          443
        ];
        allowedUDPPorts = [ 443 ];
      };
      preservation.preserveAt."/persist".directories = [
        {
          directory = config.services.caddy.dataDir;
          user = config.services.caddy.user;
          group = config.services.caddy.group;
          mode = "0700";
        }
        {
          directory = config.services.caddy.logDir;
          user = config.services.caddy.user;
          group = config.services.caddy.group;
          mode = "0750";
        }
      ];
    };
}
