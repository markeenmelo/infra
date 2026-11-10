{ config, lib, ... }:
let
  inherit (config.flake.modules.nixos) postgresql;
  inherit (config.fleet) domain hosts;
  port = 2283;
  root = "/srv/immich";
  hostname = "photos.${domain}";
in
{
  flake.checks = lib.foldlAttrs (
    acc: host: nixos:
    let
      inherit (nixos.config.services) immich;
    in
    if !immich.enable then
      acc
    else
      lib.recursiveUpdate acc {
        ${nixos.config.nixpkgs.hostPlatform.system}."immich-${host}" =
          nixos.pkgs.runCommand "immich-${host}" { }
            ''
              IMMICH_ALLOW_SETUP=${lib.escapeShellArg immich.environment.IMMICH_ALLOW_SETUP} \
                ${lib.getExe nixos.pkgs.nodejs} <<'JS'
              const load = require('node:module').createRequire('${immich.package}/lib/node_modules/immich/package.json');
              const { ConfigRepository } = load('./dist/repositories/config.repository');
              if (new ConfigRepository().getEnv().setup.allow) throw new Error('admin sign-up is still offered');
              const { AdminConfigDto, defaults } = load('./dist/dtos/config.dto');
              const settings = ${
                lib.toJSON (
                  lib.recursiveUpdate immich.settings { oauth.clientSecret = "test-only-not-a-credential"; }
                )
              };
              AdminConfigDto.schema.parse(load('lodash-es').defaultsDeep(settings, defaults));
              JS
              touch $out
            '';
      }
  ) { } config.flake.nixosConfigurations;

  flake.modules.nixos.base =
    { lib, ... }:
    {
      options.fleet.renderDevice = lib.mkOption {
        type = lib.types.str;
        description = "Stable path of the host's GPU render node, for apps that transcode or run models on it.";
      };
    };

  flake.modules.nixos.immich =
    { config, utils, ... }:
    let
      gpu = "${utils.escapeSystemdPath config.fleet.renderDevice}.device";
    in
    {
      imports = [ postgresql ];
      # the ids that own tank/immich, allocated by the old generation
      users.users.immich.uid = 983;
      users.groups.immich.gid = 985;
      sops.secrets.immich-oidc-client-secret = {
        key = "immich/oidc-client-secret";
        restartUnits = [ "immich-server.service" ];
      };
      services = {
        immich = {
          enable = true;
          host = "0.0.0.0";
          inherit port;
          mediaLocation = "${root}/library";
          accelerationDevices = [ "${config.fleet.renderDevice} rw" ];
          environment = {
            IMMICH_ALLOW_SETUP = "false";
            IMMICH_TRUSTED_PROXIES = "127.0.0.1,${hosts.racknerd.tailnetAddress}";
          };
          settings = {
            server.externalDomain = "https://${hostname}";
            ffmpeg = {
              accel = "qsv";
              preferredHwDevice = "auto";
            };
            backup.database.enabled = false;
            passwordLogin.enabled = false;
            oauth = {
              enabled = true;
              issuerUrl = "https://auth.${domain}";
              clientId = "immich";
              clientSecret._secret = config.sops.secrets.immich-oidc-client-secret.path;
              tokenEndpointAuthMethod = "client_secret_basic";
              buttonText = "Log in with Authelia";
              autoRegister = false;
            };
          };
        };
        redis.servers.immich.appendOnly = true;
      };
      fleet = {
        web.apps.photos = {
          inherit port;
          public = true;
          denied = [
            "path /api/admin/* /api/auth/admin-sign-up /api/system-config* /api/system-metadata* /api/jobs* /api/queues* /api/libraries*"
          ];
        };
        oidc.clients.immich = {
          client_name = "Immich";
          redirect_uris = [
            "https://${hostname}/auth/login"
            "https://${hostname}/user-settings"
            "app.immich:///oauth-callback"
          ];
        };
      };
      systemd.services = {
        immich-server = {
          requires = [ "redis-immich.service" ];
          wants = [ gpu ];
          after = [
            "redis-immich.service"
            gpu
          ];
          unitConfig.RequiresMountsFor = root;
          serviceConfig.SupplementaryGroups = [ "render" ];
        };
        immich-machine-learning = {
          wants = [ gpu ];
          after = [ gpu ];
          serviceConfig.SupplementaryGroups = [ "render" ];
        };
      };
      preservation.preserveAt."/persist".directories = [
        {
          directory = "/var/lib/redis-immich";
          user = "redis-immich";
          group = "redis-immich";
          mode = "0700";
        }
        {
          directory = "/var/cache/immich";
          user = "immich";
          group = "immich";
          mode = "0700";
        }
      ];
    };
}
