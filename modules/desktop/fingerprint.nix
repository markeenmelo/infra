{
  flake.modules.nixos.desktop =
    {
      config,
      lib,
      ...
    }:
    {
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
          greetd.rules.auth.login.modulePath = lib.mkForce "noctalia-greetd";
          noctalia-greetd = {
            fprintAuth = true;
            enableGnomeKeyring = true;
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
        environment.persistence."/persist".directories = [
          {
            directory = "/var/lib/fprint";
            mode = "0700";
          }
        ];
      };
    };
}
