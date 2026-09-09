{
  flake.modules.nixos.access =
    { config, lib, ... }:
    let
      inherit (lib) mkOption types;
      cfg = config.fleet.access;
    in
    {
      options.fleet.access = {
        admin = mkOption {
          type = types.nullOr (types.strMatching "[a-z_][a-z0-9_-]*");
          default = null;
          description = "Real administration account name, not inferred from the repository owner.";
        };
        authorizedKeys = mkOption {
          type = types.listOf types.nonEmptyStr;
          default = [ ];
          description = "Public SSH keys only; verify fingerprints out of band.";
        };
        passwordFile = mkOption {
          type = types.nullOr (types.strMatching "/persist/secrets/[a-zA-Z0-9_-][a-zA-Z0-9._-]*");
          default = null;
          description = "Runtime file containing a password hash; provision securely before installation. Not a Nix store path.";
        };
        passwordlessSudo = mkOption {
          type = types.bool;
          default = false;
          description = "Explicit root-equivalent privilege for the admin, if unattended deployment is required.";
        };
      };
      config = {
        fleet.bootstrap.missing =
          lib.optional (cfg.admin == null) "Set fleet.access.admin."
          ++ lib.optional (cfg.authorizedKeys == [ ]) "Supply verified public fleet.access.authorizedKeys."
          ++ lib.optional (
            cfg.passwordFile == null && !cfg.passwordlessSudo
          ) "Supply a runtime admin password hash file or explicitly approve passwordlessSudo.";
        users.mutableUsers = false;
        users.users = {
          root.hashedPassword = "!";
        }
        // lib.optionalAttrs (cfg.admin != null) {
          ${cfg.admin} = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            openssh.authorizedKeys.keys = cfg.authorizedKeys;
            hashedPassword = lib.mkIf (cfg.passwordFile == null) "!";
            hashedPasswordFile = lib.mkIf (cfg.passwordFile != null) cfg.passwordFile;
          };
        };
        security.sudo.extraRules = lib.optional (cfg.admin != null && cfg.passwordlessSudo) {
          users = [ cfg.admin ];
          commands = [
            {
              command = "ALL";
              options = [ "NOPASSWD" ];
            }
          ];
        };
      };
    };
}
