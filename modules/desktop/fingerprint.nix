{
  flake.modules.nixos.hyprland =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      # fprintd.enable normally enables fingerprint PAM on ALL services. Extend
      # the existing PAM submodule with a safer default, then opt in narrowly.
      options.security.pam.services = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            fprintAuth = lib.mkDefault false;
          }
        );
      };
      config = {
        services.fprintd.enable = true;
        security.pam.services = {
          # greetd normally delegates to login. Keep console login password-only
          # and provide a separate graphical stack with the standard final deny.
          greetd.rules = {
            auth.login.modulePath = lib.mkForce "noctalia-greetd";
            # greetd disables generated PAM rules: enableGnomeKeyring there is
            # ineffective. Keep login's session/account/recovery stack and add
            # only the keyring session hook for the token stashed below.
            session.gnome_keyring = {
              order = config.security.pam.services.greetd.rules.session.login.order + 10;
              control = "optional";
              modulePath = "${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so";
              settings.auto_start = true;
            };
          };
          noctalia-greetd = {
            fprintAuth = true;
            allowNullPassword = false;
            enableGnomeKeyring = true;
            # Native unix-early collects the password before stashing it for
            # the keyring. Reuse it exactly once: an empty/wrong submission must
            # reach fingerprint fallback, not ask for that password twice.
            rules.auth.unix.settings = {
              try_first_pass = lib.mkForce false;
              use_first_pass = true;
            };
            rules.auth.fprintd = {
              order = config.security.pam.services.noctalia-greetd.rules.auth.unix.order + 10;
              settings = {
                timeout = 10;
                "max-tries" = 2;
              };
            };
          };
          sudo = {
            fprintAuth = true;
            allowNullPassword = false;
            rules.auth.fprintd = {
              order = config.security.pam.services.sudo.rules.auth.unix.order + 10;
              settings = {
                timeout = 10;
                "max-tries" = 2;
              };
            };
          };
        };
        assertions = [
          {
            assertion =
              lib.attrNames (lib.filterAttrs (_: service: service.fprintAuth) config.security.pam.services) == [
                "noctalia-greetd"
                "sudo"
              ];
            message = "Fingerprint PAM is permitted only for the graphical greeter and ThinkPad sudo; preserve SSH and console recovery policy.";
          }
          {
            assertion =
              lib.all
                (
                  name:
                  let
                    pam = config.security.pam.services.${name};
                  in
                  !pam.allowNullPassword
                  && !pam.rules.auth.unix.settings.nullok
                  && pam.rules.auth.unix.enable
                  && pam.rules.auth.unix.control == "sufficient"
                  && pam.rules.auth.fprintd.control == "sufficient"
                  && pam.rules.auth.deny.enable
                  && pam.rules.auth.deny.control == "required"
                  && pam.rules.auth.unix.order < pam.rules.auth.fprintd.order
                  && pam.rules.auth.fprintd.order < pam.rules.auth.deny.order
                )
                [
                  "noctalia-greetd"
                  "sudo"
                ];
            message = "Desktop PAM must remain password-first, reject empty passwords and retain its final deny rule.";
          }
        ];
        # Native Noctalia locking uses fprintd alongside its password field.
        # Templates are sensitive identity state: persist, never export/enroll here.
        environment.persistence."/persist".directories = [
          {
            directory = "/var/lib/fprint";
            mode = "0700";
          }
          {
            directory = "/var/lib/AccountsService";
            mode = "0700";
          }
          {
            directory = "/var/lib/noctalia-greeter";
            user = config.services.greetd.settings.default_session.user;
            group = config.users.users.${config.services.greetd.settings.default_session.user}.group;
            mode = "0750";
          }
        ];
        # First-boot acceptance 2026-09-10: the upstream accounts-daemon unit
        # hardcodes StateDirectoryMode=0775, which systemd re-enforces on every
        # start and which silently reverted the persisted 0700 backing mode.
        # Force the reviewed private mode; the root daemon needs no group bits.
        systemd.services.accounts-daemon.serviceConfig.StateDirectoryMode =
          lib.mkForce "0700";
      };
    };
}
