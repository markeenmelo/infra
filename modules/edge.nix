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
      apps = {
        auth = 9091;
        cloud = 8081;
        home = 8123;
        jellyfin = 8096;
        photos = 2283;
      };
      jellyfin = "(?i)^/(emby/|mediabrowser/)?";
      denied = {
        home = [ "path /api/onboarding* /onboarding.html*" ];
        jellyfin = [
          "path_regexp ${jellyfin}(Backup|Devices|Plugins|Packages|Repositories|Environment|ScheduledTasks|Startup|Auth/Keys|Library/(VirtualFolders|Refresh)|LiveTv/(TunerHosts|ListingProviders)|Items/(RemoteSearch/Apply|[^/]+/(Refresh|ContentType|RemoteImages/Download))|Videos/(MergeVersions|[^/]+/AlternateSources)|Library/(Media|Movies|Series)/(Added|Updated)|System/(ActivityLog|Configuration|Restart|Shutdown|Logs)|Users/(New|Password|[^/]+/(Policy|Password))|sso/((OID|SAML)/((Add|Del)/|(Get|States)/?$)|Unregister/))"
          "method DELETE\n  path_regexp ${jellyfin}Users/[^/]+/?$"
          "method DELETE POST\n  path_regexp ${jellyfin}Items(/[^/]+(/Images(/.*)?)?)?/?$"
        ];
      };
      site =
        name: port:
        ''
          @${name} host ${name}.${domain}
          handle @${name} {
        ''
        + lib.concatImapStrings (i: matcher: ''
          @${name}-denied-${toString i} {
            ${matcher}
          }
          respond @${name}-denied-${toString i} 403
        '') (denied.${name} or [ ])
        + ''
            reverse_proxy ${bastion}:${toString port}
          }
        '';
    in
    {
      sops = {
        secrets = lib.genAttrs [ "PORKBUN_API_KEY" "PORKBUN_SECRET_KEY" ] (key: {
          sopsFile = ../secrets/porkbun/api.yaml;
          restartUnits = [ "caddy.service" ];
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
          plugins = [ "github.com/caddy-dns/porkbun@v0.3.1" ];
          hash = "sha256-3XnnBdOW8A+LmmcqR94v1ZkyMoMB3EfBWFv0uBzz4cA=";
        };
        environmentFile = config.sops.templates.caddy-env.path;
        globalConfig = "grace_period 10s";
        virtualHosts."*.${domain}" = {
          logFormat = ''
            output file ${config.services.caddy.logDir}/access.log {
              mode 0640
            }
            format filter {
              wrap json
              fields {
                request>headers>X-Emby-Token delete
                request>headers>X-Mediabrowser-Token delete
                request>headers>X-Emby-Authorization delete
                request>headers>X-Api-Key delete
                request>headers>X-Immich-User-Token delete
                request>headers>X-Immich-Session-Token delete
                request>headers>X-Immich-Share-Key delete
                request>headers>Referer delete
                request>uri regexp "[?].*" ""
              }
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
              Strict-Transport-Security "max-age=31536000; includeSubDomains"
              X-Content-Type-Options nosniff
              Referrer-Policy no-referrer
              X-Robots-Tag "noindex, nofollow, noarchive, nosnippet, noimageindex"
              -Server
            }
            request_header -Remote-User
            request_header -Remote-Groups
            request_header -Remote-Email
            request_header -Remote-Name
            ${lib.concatStrings (lib.mapAttrsToList site apps)}
            handle {
              abort
            }
          '';
        };
      };
      systemd.services.caddy = {
        wants = [ "tailscaled.service" ];
        after = [ "tailscaled.service" ];
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
