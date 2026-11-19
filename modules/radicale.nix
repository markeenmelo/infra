{ config, ... }:
let
  inherit (config.fleet) domain;
  port = 5232;
  root = "/srv/radicale";
  collections = "${root}/collections/collection-root";
  shared = "family";
in
{
  flake.modules.nixos.radicale =
    { config, lib, ... }:
    let
      inherit (config.services.radicale) user group;
      hashes = lib.listToAttrs (
        map (name: lib.nameValuePair name "authelia-${name}-password-hash") (
          lib.attrNames config.fleet.people
        )
        ++ [ (lib.nameValuePair "hermes" "radicale-hermes-password-hash") ]
      );
      accounts = lib.attrNames hashes;
      owned = {
        inherit user group;
        mode = "0750";
      };
    in
    {
      users.users.${user}.uid = 359;
      users.groups.${group}.gid = 359;
      sops = {
        secrets.radicale-hermes-password-hash.key = "radicale/hermes-password-hash";
        templates.radicale-users = {
          content = lib.concatStrings (
            lib.mapAttrsToList (name: secret: "${name}:${config.sops.placeholder.${secret}}\n") hashes
          );
          restartUnits = [ "radicale.service" ];
        };
      };
      services.radicale = {
        enable = true;
        settings = {
          server.hosts = [ "127.0.0.1:${toString port}" ];
          auth = {
            type = "htpasswd";
            htpasswd_filename = "/run/credentials/radicale.service/users";
            htpasswd_encryption = "autodetect";
            cache_logins = true;
          };
          storage.filesystem_folder = dirOf collections;
        };
        rights = {
          root = {
            user = ".+";
            collection = "";
            permissions = "R";
          };
          principal = {
            user = ".+";
            collection = "{user}";
            permissions = "RW";
          };
          calendars = {
            user = ".+";
            collection = "{user}/(?!${shared}$)[^/]+";
            permissions = "rw";
          };
          ${shared} = {
            user = ".+";
            collection = "{user}/${shared}";
            permissions = "rwdo";
          };
        };
      };
      systemd = {
        services.radicale = {
          unitConfig.RequiresMountsFor = root;
          serviceConfig = {
            ExecStartPre = "+${lib.getExe' config.systemd.package "systemd-tmpfiles"} --create --prefix=${root}";
            LoadCredential = [ "users:${config.sops.templates.radicale-users.path}" ];
            IPAddressAllow = "localhost";
            IPAddressDeny = "any";
          };
        };
        tmpfiles.settings.radicale = lib.mkMerge (
          [
            {
              ${root}.d = owned;
              ${dirOf collections}.d = owned;
              ${collections}.d = owned;
              "${collections}/shared".d = owned;
              "${collections}/shared/${shared}".d = owned;
              "${collections}/shared/${shared}/.Radicale.props".f = {
                inherit user group;
                mode = "0640";
                argument = builtins.toJSON {
                  tag = "VCALENDAR";
                  "D:displayname" = "Family";
                };
              };
            }
          ]
          ++ map (name: {
            "${collections}/${name}".d = owned;
            "${collections}/${name}/${shared}".L.argument = "../shared/${shared}";
          }) accounts
        );
      };
      services.crowdsec.settings.scenarios = [
        {
          name = "fleet/calendar-sign-in";
          description = "Repeated refused sign-ins on the calendar, which checks the household's Authelia passwords";
          filter = "evt.Meta.log_type == 'http_access-log' && evt.Line.Raw contains '\"host\":\"cal.${domain}\"' && evt.Line.Raw contains '\"status\":401'";
          type = "leaky";
          groupby = "evt.Meta.source_ip";
          capacity = 10;
          leakspeed = "1m";
          blackhole = "5m";
          labels = {
            service = "http";
            type = "bruteforce";
            remediation = true;
            confidence = 3;
            spoofable = 0;
            label = "Calendar sign-in";
          };
        }
      ];
      fleet.web.apps.cal = {
        inherit port;
        public = true;
      };
    };
}
