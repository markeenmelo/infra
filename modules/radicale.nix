let
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
      accounts = lib.attrNames config.fleet.people ++ [ "hermes" ];
      owned = {
        inherit user group;
        mode = "0750";
      };
    in
    {
      users.users.${user}.uid = 359;
      users.groups.${group}.gid = 359;
      sops = {
        secrets = lib.genAttrs' accounts (
          name: lib.nameValuePair "radicale-${name}-password-hash" { key = "radicale/${name}-password-hash"; }
        );
        templates.radicale-users = {
          content = lib.concatMapStrings (
            name: "${name}:${config.sops.placeholder."radicale-${name}-password-hash"}\n"
          ) accounts;
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
            htpasswd_encryption = "bcrypt";
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
            collection = "{user}/[^/]+";
            permissions = "rw";
          };
        };
      };
      systemd = {
        services.radicale = {
          unitConfig.RequiresMountsFor = root;
          serviceConfig = {
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
      fleet.web.apps.cal = {
        inherit port;
        public = true;
      };
    };
}
