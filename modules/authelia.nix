{ config, lib, ... }:
let
  inherit (config.flake.modules.nixos) postgresql;
  inherit (config.fleet) domain;
  name = "authelia-main";
  port = 9091;
  credentials = "/run/credentials/${name}.service";
  hostname = "auth.${domain}";
in
{
  flake.checks = lib.foldlAttrs (
    acc: host: fleetHost:
    let
      nixos = config.flake.nixosConfigurations.${host};
      instance = nixos.config.services.authelia.instances.main or { enable = false; };
      configs = lib.splitString "," (
        lib.removePrefix "${lib.getExe instance.package} --config "
          nixos.config.systemd.services.${name}.serviceConfig.ExecStart
      );
    in
    if lib.hasSuffix "-darwin" fleetHost.system || !instance.enable then
      acc
    else
      lib.recursiveUpdate acc {
        ${fleetHost.system}."authelia-${host}" =
          assert lib.assertMsg (
            instance.settings.access_control.default_policy == "deny"
          ) "Authelia's access_control.default_policy must stay deny";
          nixos.pkgs.runCommand "authelia-${host}" { } ''
            mkdir credentials
            printf '%064d' 0 > secret
            cp secret credentials/smtp-password
            printf '{"users":{"check":{"displayname":"Check","email":"check@example.org","groups":[],"password":"%s"}}}' \
              "$(${lib.getExe instance.package} crypto hash generate argon2 --password test-only-not-a-credential | ${lib.getExe nixos.pkgs.gawk} '/Digest:/{print $2}')" \
              > credentials/users
            files=()
            for source in ${lib.escapeShellArgs configs}; do
              ${lib.getExe nixos.pkgs.gnused} "s@${credentials}@$PWD/credentials@g" "$source" > "$(basename "$source")"
              files+=("$PWD/$(basename "$source")")
            done
            export AUTHELIA_IDENTITY_VALIDATION_RESET_PASSWORD_JWT_SECRET_FILE=$PWD/secret
            export AUTHELIA_STORAGE_ENCRYPTION_KEY_FILE=$PWD/secret
            export AUTHELIA_NOTIFIER_SMTP_PASSWORD_FILE=$PWD/credentials/smtp-password
            (IFS=,; ${lib.getExe instance.package} --config "''${files[*]}" validate-config)
            touch $out
          '';
      }
  ) { } config.fleet.hosts;

  flake.modules.nixos.authelia =
    { config, lib, ... }:
    let
      people = {
        marcos = {
          displayname = "Marcos Melo";
          email = "marcosmelo@proton.me";
        };
        nara = {
          displayname = "Nara";
          email = "naralidy@hotmail.com";
        };
      };
      secret = key: {
        sopsFile = ../secrets/hosts/${config.networking.hostName}.yaml;
        key = "authelia/${key}";
        restartUnits = [ "${name}.service" ];
      };
    in
    {
      imports = [ postgresql ];
      sops = {
        secrets = lib.listToAttrs (
          map (key: lib.nameValuePair "authelia-${key}" (secret key)) (
            [
              "jwt"
              "storage"
              "smtp-password"
            ]
            ++ map (user: "${user}-password-hash") (lib.attrNames people)
          )
        );
        templates.authelia-users = {
          content = builtins.toJSON {
            users = lib.mapAttrs (user: person: {
              inherit (person) displayname email;
              password = config.sops.placeholder."authelia-${user}-password-hash";
              groups = [ ];
            }) people;
          };
          restartUnits = [ "${name}.service" ];
        };
      };
      services = {
        authelia.instances.main = {
          enable = true;
          secrets = {
            jwtSecretFile = config.sops.secrets.authelia-jwt.path;
            storageEncryptionKeyFile = config.sops.secrets.authelia-storage.path;
          };
          environmentVariables.AUTHELIA_NOTIFIER_SMTP_PASSWORD_FILE = "${credentials}/smtp-password";
          settings = {
            server.address = "tcp://0.0.0.0:${toString port}/";
            log.level = "warn";
            default_2fa_method = "webauthn";
            identity_validation.elevated_session = {
              require_second_factor = true;
              skip_second_factor = true;
            };
            regulation = {
              modes = [ "ip" ];
              find_time = "10m";
              ban_time = "1h";
            };
            totp.issuer = domain;
            webauthn = {
              display_name = domain;
              selection_criteria.user_verification = "required";
            };
            authentication_backend = {
              file.path = "${credentials}/users";
              password_reset.disable = true;
              password_change.disable = true;
            };
            access_control = {
              default_policy = "deny";
              rules = [
                {
                  domain = [ hostname ];
                  policy = "two_factor";
                }
              ];
            };
            session = {
              name = "__Secure-authelia_session";
              remember_me = -1;
              cookies = [
                {
                  domain = hostname;
                  authelia_url = "https://${hostname}";
                }
              ];
            };
            storage.postgres = {
              address = "unix:///run/postgresql";
              database = name;
              username = name;
            };
            notifier.smtp = {
              address = "submissions://disroot.org:465";
              username = "kof@disroot.org";
              sender = "Authelia <kof@disroot.org>";
            };
          };
        };
        postgresql = {
          ensureDatabases = [ name ];
          ensureUsers = [
            {
              inherit name;
              ensureDBOwnership = true;
            }
          ];
        };
        caddy.virtualHosts."*.${domain}".extraConfig = ''
          @auth host ${hostname}
          handle @auth {
            reverse_proxy 127.0.0.1:${toString port}
          }
        '';
      };
      systemd.services.${name} = {
        requires = [ "postgresql.target" ];
        after = [ "postgresql.target" ];
        serviceConfig.LoadCredential = [
          "smtp-password:${config.sops.secrets.authelia-smtp-password.path}"
          "users:${config.sops.templates.authelia-users.path}"
        ];
      };
      networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = [
        port
      ];
    };
}
