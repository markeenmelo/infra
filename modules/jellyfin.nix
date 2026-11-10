{ config, inputs, ... }:
let
  inherit (config.flake.modules.nixos) nixflix;
  inherit (config.fleet) domain hosts;
  port = 8096;
  hostname = "jellyfin.${domain}";
  api = "(?i)^/(emby/|mediabrowser/)?";
  groups = {
    users = "jellyfin";
    admins = "jellyfin-admins";
  };
in
{
  flake.modules.nixos.jellyfin =
    {
      config,
      lib,
      pkgs,
      utils,
      ...
    }:
    let
      cfg = config.nixflix.jellyfin;
      gpu = "${utils.escapeSystemdPath config.fleet.renderDevice}.device";
      media = dirOf config.nixflix.mediaDir;
      secret = name: { _secret = config.sops.secrets."jellyfin-${name}".path; };
      sso = pkgs.callPackage ./jellyfin-sso.pkg.nix { };
      autheliaUsers = map lib.toLower (
        lib.attrNames
          (builtins.fromJSON (config.sops.templates.authelia-users.content or ''{"users":{}}'')).users
      );
    in
    {
      imports = [ nixflix ];
      assertions = [
        {
          assertion = lib.all (
            user: cfg.users.${user}.policy.isAdministrator || !lib.elem (lib.toLower user) autheliaUsers
          ) (lib.attrNames cfg.users);
          message = "A non-admin Jellyfin user must not share an Authelia username: an SSO login adopts the account and replaces its password and admin status.";
        }
      ];
      sops.secrets =
        lib.mapAttrs'
          (name: units: {
            name = "jellyfin-${name}";
            value = {
              key = "jellyfin/${name}";
              restartUnits = map (unit: "${unit}.service") units;
            };
          })
          {
            api-key = [
              "jellyfin"
              "jellyfin-api-key"
            ];
            password = [ "jellyfin-users-config" ];
            ian-password = [ "jellyfin-users-config" ];
            oidc-client-secret = [ "jellyfin-plugins" ];
          };
      nixflix.jellyfin = {
        enable = true;
        apiKey = secret "api-key";
        cacheDir = "${media}/cache/jellyfin";
        network = {
          internalHttpPort = port;
          localNetworkAddresses = [ "0.0.0.0" ];
          autoDiscovery = false;
          knownProxies = [
            "127.0.0.1"
            hosts.racknerd.tailnetAddress
          ];
          publicHttpsPort = 443;
        };
        encoding = {
          hardwareAccelerationType = "qsv";
          qsvDevice = config.fleet.renderDevice;
          hardwareDecodingCodecs = [
            "h264"
            "hevc"
            "mpeg2video"
            "vc1"
            "vp9"
            "av1"
          ];
          enableTonemapping = true;
          enableIntelLowPowerH264HwEncoder = true;
          enableIntelLowPowerHevcHwEncoder = true;
        };
        system = {
          metadataPath = "${cfg.dataDir}/metadata";
          quickConnectAvailable = true;
          trickplayOptions = {
            enableHwAcceleration = true;
            enableHwEncoding = true;
          };
        };
        users.marcos = {
          mutable = false;
          password = secret "password";
          policy = {
            isAdministrator = true;
            enableRemoteAccess = true;
          };
        };
        users.ian = {
          mutable = false;
          password = secret "ian-password";
          policy = {
            # Jellyfin's score for PG and TV-PG
            maxParentalRating = 10;
            blockUnratedItems = [
              "Movie"
              "Series"
            ];
          };
        };
        libraries =
          lib.mapAttrs
            (_: library: {
              collectionType = lib.mkDefault library.type;
              paths = lib.mkDefault [ "${config.nixflix.mediaDir}/${library.dir}" ];
              saveTrickplayWithMedia = true;
              subtitleDownloadLanguages = [
                "eng"
                "fra"
                "pob"
              ];
            })
            {
              Movies = {
                type = "movies";
                dir = "movies";
              };
              Shows = {
                type = "tvshows";
                dir = "tv";
              };
            };
        plugins = {
          "Intro Skipper".enable = true;
          subbuzz = {
            enable = true;
            config = {
              EnableAddic7ed = true;
              EnablePodnapisiNet = true;
              EnableYifySubtitles = true;
            };
          };
          "Subtitle Extract" = {
            enable = true;
            config.ExtractionDuringLibraryScan = true;
          };
          "TMDb Box Sets".enable = true;
          Fanart.enable = true;
          # shortcut: nixflix's plugin manifest has no Jellyfin 12 build of the SSO plugin; use its package once it lists K0lin's 5.x
          "SSO Authentication" = {
            enable = true;
            apiName = "SSO-Auth";
            package = inputs.nixflix.lib.buildJellyfinPlugin { inherit pkgs; } {
              inherit (sso) pname version src;
              passthru.pluginDirName = "SSO Authentication";
            };
            config.OidConfigs.authelia = {
              Enabled = true;
              OidEndpoint = "https://auth.${domain}";
              OidClientId = "jellyfin";
              OidSecret = secret "oidc-client-secret";
              OidScopes = [ "groups" ];
              RoleClaim = "groups";
              EnableAuthorization = true;
              Roles = lib.attrValues groups;
              AdminRoles = [ groups.admins ];
              EnableAllFolders = true;
              DefaultUsernameClaim = "preferred_username";
              SchemeOverride = "https";
              # shortcut: OidcClient 7.1.0 sends PAR with basic auth but the token request with post (DuendeSoftware/foss#349); drop once the plugin ships foss#351
              DisablePushedAuthorization = true;
            };
          };
        };
        branding.loginDisclaimer = ''
          <form action="https://${hostname}/sso/OID/start/authelia">
            <button class="raised block emby-button button-submit">Sign in with Authelia</button>
          </form>
        '';
      };
      fleet = {
        web.apps.jellyfin = {
          inherit port;
          public = true;
          denied = [
            "path_regexp ${api}(Backup|Devices|Plugins|Packages|Repositories|Environment|ScheduledTasks|Startup|Auth/Keys|Library/(VirtualFolders|Refresh)|LiveTv/(TunerHosts|ListingProviders)|Items/(RemoteSearch/Apply|[^/]+/(Refresh|ContentType|RemoteImages/Download))|Videos/(MergeVersions|[^/]+/AlternateSources)|Library/(Media|Movies|Series)/(Added|Updated)|System/(ActivityLog|Configuration|Restart|Shutdown|Logs)|Users/(New|Password|Policy|[^/]+/(Policy|Password))|sso/((OID|SAML)/((Add|Del)/|(Get|States)/?$)|Unregister/))"
            "path_regexp ${api}Users/(AuthenticateByName|[^/]+/Authenticate)/?$"
            "method DELETE\n  path_regexp ${api}Users/[^/]+/?$"
            "method DELETE POST\n  path_regexp ${api}Items(/[^/]+(/Images(/.*)?)?)?/?$"
          ];
        };
        oidc.clients.jellyfin = {
          client_name = "Jellyfin";
          token_endpoint_auth_method = "client_secret_post";
          redirect_uris = [ "https://${hostname}/sso/OID/redirect/authelia" ];
          scopes = [
            "openid"
            "profile"
            "email"
            "groups"
          ];
        };
      };
      systemd.services.jellyfin = {
        wants = [ gpu ];
        after = [ gpu ];
        unitConfig.RequiresMountsFor = [
          config.nixflix.stateDir
          media
        ];
        serviceConfig = {
          DevicePolicy = "closed";
          DeviceAllow = [ "${config.fleet.renderDevice} rw" ];
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = [
            cfg.dataDir
            cfg.cacheDir
            config.nixflix.mediaDir
          ];
          CapabilityBoundingSet = "";
        };
      };
    };
}
