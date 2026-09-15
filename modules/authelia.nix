{
  fleet.hosts.racknerd.module =
    { config, lib, ... }:
    let
      inherit (lib) mkOption types;
      cfg = config.fleet.authentication;
      web = config.fleet.web;
      smtp = cfg.notifier == "smtp";
      requiredSecrets = if smtp then cfg.secrets else builtins.removeAttrs cfg.secrets [ "smtpPassword" ];
      nullable =
        type: description:
        mkOption {
          type = types.nullOr type;
          default = null;
          inherit description;
        };
      secretPath =
        name:
        if
          name != null
          && builtins.hasAttr name config.sops.secrets
          && config.sops.secrets.${name}.owner == "root"
          && config.sops.secrets.${name}.mode == "0400"
        then
          config.sops.secrets.${name}.path
        else
          "";
      address = toString web.authAddress;
      family = if lib.hasInfix ":" (toString cfg.bastionAddress) then "ip6" else "ip";
      remoteRule = ''iifname "tailscale0" ${family} saddr ${toString cfg.bastionAddress} tcp dport 9091'';
    in
    {
      options.fleet.authentication = {
        notifier = mkOption {
          type = types.enum [
            "filesystem"
            "smtp"
          ];
          default = "filesystem";
          description = "Explicit notification transport; filesystem is temporary operator-mediated enrollment, never an automatic SMTP fallback.";
        };
        bastionAddress = mkOption {
          type = types.nullOr (
            types.strMatching "(100\\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\\.[0-9]{1,3}\\.[0-9]{1,3}|fd7a:115c:a1e0:[0-9a-f:]+)"
          );
          default = "100.105.158.109";
          description = "Verified Bastion Tailscale source IP; also commission the exact private tailnet ACL.";
        };
        smtpAddress = nullable (types.strMatching "(smtp|submissions)://[a-zA-Z0-9.-]+:[0-9]+") "Verified TLS-validating SMTP endpoint; smtp requires STARTTLS, submissions uses implicit TLS.";
        smtpUsername = nullable types.nonEmptyStr "Verified SMTP login name.";
        smtpSender = nullable types.nonEmptyStr "Verified notification sender.";
        secrets = lib.genAttrs [ "jwt" "storage" "users" "smtpPassword" ] (
          name: nullable types.nonEmptyStr "Declared SOPS secret name for Authelia ${name}."
        );
      };
      config = lib.mkIf web.enable {
        assertions = [
          {
            assertion = cfg.bastionAddress != null && web.authAddress != null;
            message = "Central Authelia requires verified Racknerd and Bastion Tailscale IPs and the separately commissioned exact ACL.";
          }
          {
            assertion =
              !smtp || (cfg.smtpAddress != null && cfg.smtpUsername != null && cfg.smtpSender != null);
            message = "Authelia SMTP mode requires a verified endpoint, username and sender; no startup-check bypass or automatic fallback.";
          }
          {
            assertion = lib.all (
              name: secretPath name != "" && lib.hasPrefix "/run/secrets/" (secretPath name)
            ) (builtins.attrValues requiredSecrets);
            message = "Authelia requires declared root-owned 0400 SOPS users, JWT and storage secrets, plus the SMTP password in SMTP mode.";
          }
        ];
        services.authelia.instances.main = {
          enable = true;
          secrets = {
            jwtSecretFile = "/run/credentials/authelia-main.service/jwt";
            storageEncryptionKeyFile = "/run/credentials/authelia-main.service/storage";
          };
          environmentVariables = lib.optionalAttrs smtp {
            AUTHELIA_NOTIFIER_SMTP_PASSWORD_FILE = "/run/credentials/authelia-main.service/smtpPassword";
          };
          settings = {
            server.address = "tcp://${if lib.hasInfix ":" address then "[${address}]" else address}:9091/";
            log.level = "warn";
            default_2fa_method = "webauthn";
            totp = {
              disable = false;
              issuer = toString web.domain;
            };
            webauthn = {
              disable = false;
              display_name = toString web.domain;
            };
            authentication_backend.file = {
              path = "/run/credentials/authelia-main.service/users";
              watch = false;
            };
            authentication_backend.password_reset.disable = true;
            authentication_backend.password_change.disable = true;
            access_control.default_policy = "deny";
            session = {
              name = "__Secure-authelia_session";
              same_site = "lax";
              inactivity = "5m";
              expiration = "1h";
              remember_me = "-1";
              cookies = [
                {
                  domain = toString web.domain;
                  authelia_url = "https://${toString web.authHostname}";
                }
              ];
            };
            storage.local.path = "/var/lib/authelia-main/db.sqlite3";
            notifier = {
              disable_startup_check = false;
            }
            // (
              if smtp then
                {
                  smtp = {
                    address = toString cfg.smtpAddress;
                    username = toString cfg.smtpUsername;
                    sender = toString cfg.smtpSender;
                    disable_require_tls = false;
                    tls = {
                      skip_verify = false;
                      minimum_version = "TLS1.2";
                    };
                  };
                }
              else
                {
                  filesystem.filename = "/run/authelia-main/notifications.txt";
                }
            );
          };
        };
        systemd.services.authelia-main = {
          requires = [ "tailscaled.service" ];
          after = [ "tailscaled.service" ];
          serviceConfig = {
            LoadCredential = lib.mapAttrsToList (key: name: "${key}:${secretPath name}") requiredSecrets;
          }
          // lib.optionalAttrs (!smtp) {
            RuntimeDirectory = "authelia-main";
            RuntimeDirectoryMode = "0700";
            UMask = "0077";
          };
        };
        environment.persistence."/persist".directories = [
          {
            directory = "/var/lib/authelia-main";
            user = "authelia-main";
            group = "authelia-main";
            mode = "0700";
          }
        ];
        networking.firewall.extraInputRules = "${remoteRule} accept";
        networking.nftables.tables.authelia-private = {
          family = "inet";
          content = ''
            chain input {
              type filter hook input priority -20; policy accept;
              iifname "lo" tcp dport 9091 return
              ${remoteRule} return
              tcp dport 9091 drop
            }
          '';
        };
      };
    };
}
