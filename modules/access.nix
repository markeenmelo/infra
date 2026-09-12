{ config, ... }:
let
  secretsModule = config.flake.modules.nixos.secrets;
in
{
  flake.modules.nixos.access =
    { config, lib, ... }:
    let
      inherit (lib) mkOption types;
      cfg = config.fleet.access;
      configured = secret: secret != null && builtins.hasAttr secret config.sops.secrets;
    in
    {
      imports = [ secretsModule ];
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
        passwordSecrets = mkOption {
          type = types.attrsOf (types.nullOr (types.strMatching "[a-zA-Z0-9_-][a-zA-Z0-9._-]*"));
          default = { };
          description = "Account to declared SOPS password-hash secret name. Null is a commissioning blocker, never a fake runtime file.";
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
            cfg.admin != null && !(builtins.hasAttr cfg.admin cfg.passwordSecrets) && !cfg.passwordlessSudo
          ) "Declare the admin in fleet.access.passwordSecrets or explicitly approve passwordlessSudo."
          ++ lib.mapAttrsToList (
            user: _: "Supply a declared SOPS password-hash secret in fleet.access.passwordSecrets.${user}."
          ) (lib.filterAttrs (_: secret: !configured secret) cfg.passwordSecrets);
        assertions = lib.mapAttrsToList (
          user: name:
          let
            secret = config.sops.secrets.${name};
            account = config.users.users.${user};
          in
          {
            assertion =
              account.isNormalUser
              && !config.users.mutableUsers
              && secret.name == name
              && secret.neededForUsers
              && secret.path == "/run/secrets-for-users/${secret.name}"
              && secret.mode == "0400"
              && secret.uid == 0
              && secret.gid == 0
              && lib.elem secret.owner [
                null
                "root"
              ]
              && lib.elem secret.group [
                null
                "root"
              ]
              && account.hashedPasswordFile == secret.path
              && account.hashedPassword == null
              && account.password == null
              && account.initialPassword == null
              && account.initialHashedPassword == null;
            message = "SOPS password for ${user} must be the sole credential source, root-only and neededForUsers at its early runtime path.";
          }
        ) (lib.filterAttrs (_: configured) cfg.passwordSecrets);
        users = {
          mutableUsers = false;
          users = lib.mkMerge [
            { root.hashedPassword = "!"; }
            (lib.optionalAttrs (cfg.admin != null) {
              ${cfg.admin} = {
                isNormalUser = true;
                extraGroups = [ "wheel" ];
                openssh.authorizedKeys.keys = cfg.authorizedKeys;
                hashedPassword = lib.mkIf (!(builtins.hasAttr cfg.admin cfg.passwordSecrets)) "!";
              };
            })
            (lib.mapAttrs (_: secret: {
              hashedPassword = lib.mkIf (!configured secret) "!";
              hashedPasswordFile = lib.mkIf (configured secret) config.sops.secrets.${secret}.path;
            }) cfg.passwordSecrets)
          ];
        };
        security.sudo = {
          extraRules = lib.optional (cfg.admin != null && cfg.passwordlessSudo) {
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
    };
}
