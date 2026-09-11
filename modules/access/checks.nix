{
  config,
  inputs,
  lib,
  ...
}:
let
  fixtures = config.fleet.validation.fixtures;
  sopsReport = lib.mapAttrs (
    track: fixture:
    let
      cfg = fixture.config;
      rejected =
        module:
        !(builtins.tryEval
          (fixture.extendModules { modules = [ module ]; }).config.system.build.toplevel.drvPath
        ).success;
      missing =
        (fixture.extendModules {
          modules = [ { fleet.access.passwordSecrets.fixture-admin = lib.mkForce null; } ];
        }).config;
    in
    assert lib.assertMsg (
      cfg.users.users.fixture-admin.hashedPasswordFile == cfg.sops.secrets.TEST-ONLY-password.path
      && cfg.sops.secrets.TEST-ONLY-password.path == "/run/secrets-for-users/TEST-ONLY-password"
      && cfg.sops.secrets.TEST-ONLY-password.neededForUsers
      && cfg.sops.secrets.TEST-ONLY-password.mode == "0400"
      && !cfg.users.mutableUsers
      && cfg.security.sudo.wheelNeedsPassword
      && !cfg.fleet.access.passwordlessSudo
      && lib.elem "setupSecretsForUsers" cfg.system.activationScripts.users.deps
      && lib.elem "specialfs" cfg.system.activationScripts.setupSecretsForUsers.deps
      && cfg.sops.age.keyFile == cfg.fleet.secrets.ageKeyFile
      && cfg.sops.age.sshKeyPaths == [ ]
      && cfg.sops.gnupg.sshKeyPaths == [ ]
      && !cfg.sops.age.generateKey
      && cfg.sops.validateSopsFiles
      && !cfg.sops.useTmpfs
      && !cfg.services.userborn.enable
      && !cfg.systemd.sysusers.enable
      && !cfg.sops.useSystemdActivation
      &&
        cfg.sops.package.drvPath == (fixture.pkgs.callPackage inputs.sops-nix { })
        .sops-install-secrets.drvPath
    ) "${track}: early SOPS password delivery or target-package isolation regressed";
    assert lib.assertMsg (
      missing.users.users.fixture-admin.hashedPassword == "!"
      && missing.users.users.fixture-admin.hashedPasswordFile == null
      && lib.elem "Supply a declared SOPS password-hash secret in fleet.access.passwordSecrets.fixture-admin." missing.fleet.bootstrap.missing
      && !(builtins.tryEval missing.system.build.toplevel.drvPath).success
    ) "${track}: missing credentials must stay locked and block commissioning";
    assert lib.all
      (
        module:
        lib.assertMsg (rejected module) "${track}: unsafe SOPS password/identity configuration was accepted"
      )
      [
        { fleet.access.passwordSecrets.fixture-admin = lib.mkForce "TEST-ONLY-UNDECLARED"; }
        { fleet.secrets.ageKeyFile = lib.mkForce null; }
        { fleet.secrets.identityReviewed = lib.mkForce false; }
        { fileSystems."/persist".neededForBoot = lib.mkForce false; }
        { sops.secrets.TEST-ONLY-password.neededForUsers = lib.mkForce false; }
        { sops.secrets.TEST-ONLY-password.mode = lib.mkForce "0444"; }
        { sops.secrets.TEST-ONLY-password.name = lib.mkForce "../TEST-ONLY-password"; }
        { users.mutableUsers = lib.mkForce true; }
        { sops.secrets.TEST-ONLY-password.path = lib.mkForce "/persist/secrets/TEST-ONLY-password"; }
        { sops.age.generateKey = lib.mkForce true; }
        { sops.age.sshKeyPaths = lib.mkForce [ "/persist/etc/ssh/ssh_host_ed25519_key" ]; }
        { sops.validateSopsFiles = lib.mkForce false; }
        { sops.useTmpfs = lib.mkForce true; }
        { services.userborn.enable = lib.mkForce true; }
        { users.users.fixture-admin.hashedPassword = "!"; }
      ];
    {
      usersManifest = cfg.system.build.sops-nix-users-manifest.drvPath;
      installer = cfg.sops.package.drvPath;
      toplevel = cfg.system.build.toplevel.drvPath;
      missingCredentialsBlocked = true;
      unsafeOverridesRejected = true;
    }
  ) fixtures;
in
{
  fleet.validation.hostChecks.secrets =
    { name, system, ... }:
    let
      cfg = system.config;
      tailscaleEnabled = cfg.fleet.tailscale.enable;
    in
    assert lib.assertMsg (
      cfg.sops.age.keyFile == cfg.fleet.secrets.ageKeyFile
      && !cfg.sops.age.generateKey
      && cfg.sops.age.sshKeyPaths == [ ]
      && cfg.sops.gnupg.sshKeyPaths == [ ]
      && cfg.sops.validateSopsFiles
      && !cfg.sops.useTmpfs
      && cfg.fleet.access.passwordSecrets ? marcos
      && (
        if name == "thinkpad" then
          cfg.fleet.access.passwordSecrets.marcos == "marcos-password-hash"
          && cfg.users.users.marcos.hashedPasswordFile == cfg.sops.secrets.marcos-password-hash.path
          && cfg.sops.secrets.marcos-password-hash.neededForUsers
          &&
            builtins.attrNames cfg.sops.secrets == (
              [ "marcos-password-hash" ]
              ++ lib.optionals (cfg.fleet.wifi.senecaSopsFile != null) [
                "seneca-identity"
                "seneca-password"
              ]
              ++ lib.optional tailscaleEnabled "tailscale-auth-key"
              ++ [ "wifi-psk" ]
            )
        else if name == "racknerd" then
          cfg.fleet.access.passwordSecrets.marcos == "marcos-password-hash"
          && cfg.users.users.marcos.hashedPasswordFile == cfg.sops.secrets.marcos-password-hash.path
          && cfg.sops.secrets.marcos-password-hash.sopsFile == ../../secrets/hosts/racknerd.yaml
          && cfg.sops.secrets.marcos-password-hash.neededForUsers
          && builtins.attrNames cfg.sops.secrets == [ "marcos-password-hash" ]
        else
          cfg.sops.secrets == { }
      )
    ) "${name}: SOPS identity/password policy regressed or unrelated secrets enabled";
    true;
  flake.validation.sops = sopsReport;
  # Test-only identity has no matching key and cannot decrypt shipped ciphertext.
  fleet.validation.fixtureModules.access = _: {
    fleet = {
      access = {
        admin = "fixture-admin";
        authorizedKeys = [ "ssh-ed25519 TEST-ONLY-NOT-A-VALID-KEY" ];
        passwordSecrets.fixture-admin = "TEST-ONLY-password";
        passwordlessSudo = false;
      };
      secrets = {
        ageKeyFile = "/persist/var/lib/sops-nix/TEST-ONLY-NO-IDENTITY";
        identityReviewed = true;
      };
    };
    sops.secrets.TEST-ONLY-password = {
      sopsFile = ../../secrets/hosts/thinkpad.yaml;
      key = "marcos-password-hash";
      neededForUsers = true;
    };
  };
  perSystem.checks = lib.mapAttrs' (
    track: fixture:
    lib.nameValuePair "${track}-sops-users-manifest" fixture.config.system.build.sops-nix-users-manifest
  ) fixtures;
}
