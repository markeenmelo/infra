{
  config,
  inputs,
  lib,
  options,
  ...
}:
let
  fixtures = config.fleet.validation.fixtures;
  deploymentPkgs = pkgs: pkgs.extend inputs.deploy-rs.overlays.default;
  report = lib.mapAttrs (
    track: fixture:
    let
      cfg = fixture.config;
      # Reuse the actual host metadata type and its deferred deployment module.
      # These hosts exist only in this isolated evaluation, never in fleet/deploy outputs.
      deploymentFor =
        sshUser:
        let
          host =
            (lib.evalModules {
              modules = [
                {
                  options.hosts = lib.mkOption { type = options.fleet.hosts.type; };
                  config.hosts.fixture = {
                    system = "x86_64-linux";
                    inherit track;
                    deployment = {
                      enable = true;
                      hostname = "evaluation-only.test";
                      transport = "trusted-user";
                      inherit sshUser;
                    };
                  };
                }
              ];
            }).config.hosts.fixture;
        in
        assert lib.assertMsg (
          host.deployment.profileUser == "root"
        ) "${track}: system activation must still default to root";
        fixture.extendModules { modules = [ host.module ]; };
      deployAdmin = deploymentFor "fixture-admin";
      deployRoot = (deploymentFor "root").extendModules {
        modules = [ { users.users.root.openssh.authorizedKeys.keys = cfg.fleet.access.authorizedKeys; } ];
      };
      deployNull = deploymentFor null;
      deployUnknown = deploymentFor "fixture-missing";
      failedAssertions =
        system: map (a: a.message) (lib.filter (a: !a.assertion) system.config.assertions);
      deployLib = (deploymentPkgs fixture.pkgs).deploy-rs.lib;
    in
    assert lib.assertMsg (lib.all
      (system: system.config.services.openssh.settings.PermitRootLogin == "no")
      [
        deployAdmin
        deployRoot
        deployNull
      ]
    ) "${track}: deployment must not relax the SSH root-login policy";
    assert lib.assertMsg (
      deployAdmin.config.fleet.bootstrap.missing == [ ] && failedAssertions deployAdmin == [ ]
    ) "${track}: keyed non-root deployment user was rejected";
    assert lib.assertMsg (
      deployRoot.config.fleet.bootstrap.missing == [ ]
      &&
        failedAssertions deployRoot == [
          "Deployment SSH user must be non-root; SSH root login is disabled."
        ]
      && !(builtins.tryEval deployRoot.config.system.build.toplevel.drvPath).success
    ) "${track}: root deployment SSH user with a public key must fail readiness/toplevel evaluation";
    assert lib.assertMsg (
      deployNull.config.fleet.bootstrap.missing == [ "Supply deployment.sshUser and verify elevation." ]
      && !(builtins.tryEval deployNull.config.system.build.toplevel.drvPath).success
    ) "${track}: missing deployment SSH user must remain a commissioning blocker";
    assert lib.assertMsg (
      failedAssertions deployUnknown == [
        "Deployment SSH user must have an explicitly configured account and public keys."
      ]
      && !(builtins.tryEval deployUnknown.config.system.build.toplevel.drvPath).success
    ) "${track}: deployment must still reject an unconfigured SSH account";
    {
      deploymentAccess = {
        nonRootToplevel = deployAdmin.config.system.build.toplevel.drvPath;
        rootRejected = true;
        nullBlocked = true;
        unknownUserRejected = true;
      };
      activation = (deployLib.activate.nixos fixture).drvPath;
    }
  ) fixtures;
in
{
  flake.validation.fixtures = report;
  perSystem.checks = lib.concatMapAttrs (
    track: fixture:
    let
      deployLib = (deploymentPkgs fixture.pkgs).deploy-rs.lib;
      # Exercise real upstream activation checks on tiny, non-system payloads.
      # The real NixOS activation derivations are evaluated separately above.
      smoke = deployLib.deployChecks {
        nodes.fixture = {
          hostname = "evaluation-only.invalid";
          profiles.smoke = {
            user = "root";
            path = deployLib.activate.custom (fixture.pkgs.runCommand "smoke-payload" { }
              ''mkdir -p "$out"''
            ) ":";
          };
        };
      };
    in
    lib.mapAttrs' (name: value: lib.nameValuePair "${track}-${name}-smoke" value) smoke
  ) fixtures;
}
