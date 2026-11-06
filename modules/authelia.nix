{ config, lib, ... }:
let
  inherit (config.flake.modules.nixos) postgresql;
  inherit (config.fleet) domain;
  name = "authelia-main";
  port = 9091;
  credentials = "/run/credentials/${name}.service";
  hostname = "auth.${domain}";
  hashes =
    clients:
    map (id: "${id}-client-secret-hash") (lib.attrNames (lib.filterAttrs (_: c: !c.public) clients));
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
      oidc = instance.settings.identity_providers.oidc;
      unsafe = lib.filter (
        client:
        client.authorization_policy != "people"
        || !client.require_pkce
        || client.pkce_challenge_method != "S256"
        || !lib.all (
          uri:
          lib.hasPrefix "https://" uri
          || builtins.match "http://(127[.]0[.]0[.]1|localhost)" uri != null
          || builtins.match "([a-z]+[.][a-z.]+|oc):/.*" uri != null
        ) client.redirect_uris
      ) oidc.clients;
    in
    if lib.hasSuffix "-darwin" fleetHost.system || !instance.enable then
      acc
    else
      lib.recursiveUpdate acc {
        ${fleetHost.system}."authelia-${host}" =
          assert lib.assertMsg (
            instance.settings.access_control.default_policy == "deny"
          ) "Authelia's access_control.default_policy must stay deny";
          assert lib.assertMsg (
            oidc.authorization_policies.people.default_policy == "deny"
            && lib.all (rule: rule.policy == "two_factor") oidc.authorization_policies.people.rules
          ) "Authelia's OIDC people policy must deny by default and require two factors";
          assert lib.assertMsg (
            nixos.config.systemd.services.${name}.environment.X_AUTHELIA_CONFIG_FILTERS or null == "template"
          ) "authelia-main must run with the template filter, or OIDC client secrets stay literal templates";
          assert lib.assertMsg (unsafe == [ ])
            "OIDC clients must keep the people policy, S256 PKCE and https or app-scheme redirects: ${
              toString (map (client: client.client_id) unsafe)
            }";
          nixos.pkgs.runCommand "authelia-${host}" { } ''
            mkdir credentials
            printf '%064d' 0 > secret
            cp secret credentials/smtp-password
            printf '{"users":{"check":{"displayname":"Check","email":"check@example.org","groups":[],"password":"%s"}}}' \
              "$(${lib.getExe instance.package} crypto hash generate argon2 --password test-only-not-a-credential | ${lib.getExe nixos.pkgs.gawk} '/Digest:/{print $2}')" \
              > credentials/users
            ${lib.getExe nixos.pkgs.openssl} genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 \
              -out credentials/oidcIssuerPrivateKeyFile 2>/dev/null
            ${lib.getExe instance.package} crypto hash generate pbkdf2 --password test-only-not-a-credential \
              | ${lib.getExe nixos.pkgs.gawk} '/Digest:/{print $2}' > hash
            test -s hash
            for file in ${lib.escapeShellArgs (hashes nixos.config.fleet.oidc.clients)}; do
              cp hash "credentials/$file"
            done
            files=()
            for source in ${lib.escapeShellArgs configs}; do
              ${lib.getExe nixos.pkgs.gnused} "s@${credentials}@$PWD/credentials@g" "$source" > "$(basename "$source")"
              files+=("$PWD/$(basename "$source")")
            done
            export X_AUTHELIA_CONFIG_FILTERS=template
            export CREDENTIALS_DIRECTORY=$PWD/credentials
            export AUTHELIA_IDENTITY_VALIDATION_RESET_PASSWORD_JWT_SECRET_FILE=$PWD/secret
            export AUTHELIA_STORAGE_ENCRYPTION_KEY_FILE=$PWD/secret
            export AUTHELIA_IDENTITY_PROVIDERS_OIDC_HMAC_SECRET_FILE=$PWD/secret
            export AUTHELIA_NOTIFIER_SMTP_PASSWORD_FILE=$PWD/credentials/smtp-password
            (IFS=,; ${lib.getExe instance.package} --config "''${files[*]}" validate-config)
            touch $out
          '';
      }
  ) { } config.fleet.hosts;

  flake.modules.nixos.base =
    { lib, ... }:
    {
      options.fleet.oidc.clients = lib.mkOption {
        default = { };
        description = "Authelia OIDC clients keyed by client_id, in Authelia's client schema. A client without `public = true` reads its secret digest from the sops key authelia/ID-client-secret-hash.";
        type = lib.types.attrsOf (
          lib.types.submodule {
            freeformType = lib.types.attrsOf lib.types.anything;
            options.public = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Whether the client authenticates without a secret.";
            };
          }
        );
      };
    };

  flake.modules.nixos.authelia =
    { config, lib, ... }:
    let
      people = {
        marcos = {
          displayname = "Marcos Melo";
          email = "marcosmelo@proton.me";
          groups = [
            "opencloudAdmin"
            "jellyfin"
            "jellyfin-admins"
          ];
        };
        nara = {
          displayname = "Nara";
          email = "naralidy@hotmail.com";
          groups = [
            "opencloudUser"
            "jellyfin"
          ];
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
              "oidc-hmac"
              "oidc-signing-key"
            ]
            ++ map (user: "${user}-password-hash") (lib.attrNames people)
            ++ hashes config.fleet.oidc.clients
          )
        );
        templates.authelia-users = {
          content = builtins.toJSON {
            users = lib.mapAttrs (user: person: {
              inherit (person) displayname email groups;
              password = config.sops.placeholder."authelia-${user}-password-hash";
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
            oidcHmacSecretFile = config.sops.secrets.authelia-oidc-hmac.path;
            oidcIssuerPrivateKeyFile = config.sops.secrets.authelia-oidc-signing-key.path;
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
            identity_providers.oidc = {
              cors = {
                endpoints = [
                  "authorization"
                  "token"
                  "revocation"
                  "introspection"
                  "userinfo"
                ];
                allowed_origins_from_client_redirect_uris = true;
              };
              authorization_policies.people = {
                default_policy = "deny";
                rules = [
                  {
                    policy = "two_factor";
                    subject = map (user: "user:${user}") (lib.attrNames people);
                  }
                ];
              };
              clients = lib.mapAttrsToList (
                client_id: client:
                lib.mergeAttrsList [
                  {
                    inherit client_id;
                    authorization_policy = "people";
                    require_pkce = true;
                    pkce_challenge_method = "S256";
                    scopes = [
                      "openid"
                      "profile"
                      "email"
                    ];
                  }
                  (
                    if client.public then
                      {
                        public = true;
                        token_endpoint_auth_method = "none";
                      }
                    else
                      { client_secret = ''{{ secret "${credentials}/${client_id}-client-secret-hash" | trim }}''; }
                  )
                  (removeAttrs client [ "public" ])
                ]
              ) config.fleet.oidc.clients;
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
      };
      fleet.web.apps.auth = {
        inherit port;
        public = true;
      };
      systemd.services.${name} = {
        requires = [ "postgresql.target" ];
        after = [ "postgresql.target" ];
        serviceConfig.LoadCredential = [
          "smtp-password:${config.sops.secrets.authelia-smtp-password.path}"
          "users:${config.sops.templates.authelia-users.path}"
        ]
        ++ map (file: "${file}:${config.sops.secrets."authelia-${file}".path}") (
          hashes config.fleet.oidc.clients
        );
      };
    };
}
