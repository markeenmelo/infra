let
  port = 5232;
  root = "/srv/radicale";
  collections = "${root}/collections/collection-root";
  shared = "family";
  route = endpoint: dav: {
    inherit endpoint;
    backend = "http://127.0.0.1:${toString port}";
    remote_user_header = "X-Remote-User";
    skip_x_access_token = true;
    additional_headers = {
      X-Script-Name = "/${dav}";
      # Radicale strips X-Script-Name only from requests that name a proxy, and OpenCloud's sets no X-Forwarded header
      X-Forwarded-Proto = "https";
    };
  };
in
{
  flake.modules.nixos.radicale =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (config.services.radicale) user group;
      owned = {
        inherit user group;
        mode = "0750";
      };
      policy = (pkgs.formats.yaml { }).generate "proxy.yaml" {
        additional_policies = [
          {
            name = "default";
            routes =
              lib.concatMap
                (dav: [
                  (route "/${dav}/" dav)
                  (route "/.well-known/${dav}" dav)
                ])
                [
                  "caldav"
                  "carddav"
                ];
          }
        ];
      };
    in
    {
      users.users.${user}.uid = 359;
      users.groups.${group}.gid = 359;
      services.radicale = {
        enable = true;
        settings = {
          server.hosts = [ "127.0.0.1:${toString port}" ];
          auth.type = "http_x_remote_user";
          web.type = "none";
          storage = {
            filesystem_folder = dirOf collections;
            predefined_collections = builtins.toJSON {
              calendar = {
                tag = "VCALENDAR";
                "D:displayname" = "Calendar";
                "C:supported-calendar-component-set" = "VEVENT,VJOURNAL,VTODO";
              };
              contacts = {
                tag = "VADDRESSBOOK";
                "D:displayname" = "Contacts";
              };
            };
          };
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
          collections = {
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
        services = {
          radicale = {
            unitConfig.RequiresMountsFor = root;
            serviceConfig = {
              ExecStartPre = "+${lib.getExe' config.systemd.package "systemd-tmpfiles"} --create --prefix=${root}";
              IPAddressAllow = "localhost";
              IPAddressDeny = "any";
            };
          };
          radicale-family = {
            description = "Link the family calendar into every Radicale home";
            after = [ "radicale.service" ];
            wantedBy = [ "radicale.service" ];
            unitConfig.RequiresMountsFor = root;
            serviceConfig = {
              Type = "oneshot";
              User = user;
              Group = group;
            };
            enableStrictShellChecks = true;
            script = ''
              shopt -s nullglob
              for home in ${collections}/*/; do
                home=''${home%/}
                [ "''${home##*/}" = shared ] && continue
                [ -e "$home/${shared}" ] || [ -L "$home/${shared}" ] || ln -s ../shared/${shared} "$home/${shared}"
              done
            '';
          };
          opencloud = {
            restartTriggers = [ policy ];
            serviceConfig.ExecStartPre = [
              "+${pkgs.coreutils}/bin/ln -sfn ${policy} ${config.services.opencloud.environment.OC_CONFIG_DIR}/proxy.yaml"
            ];
          };
        };
        paths.radicale-family = {
          wantedBy = [ "multi-user.target" ];
          pathConfig.PathChanged = collections;
        };
        tmpfiles.settings.radicale = {
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
        };
      };
      fleet.loopbackGuards.radicale = {
        ports = [ port ];
        users = [ config.services.opencloud.user ];
      };
    };
}
