{
  config,
  inputs,
  lib,
  ...
}:
let
  # Independent policy oracle: changing host metadata alone must fail validation.
  expectedTracks = {
    thinkpad = "unstable";
    dino = "unstable";
    racknerd = "stable";
    bastion = "stable";
  };
  tracks = {
    stable = inputs.nixpkgs-stable;
    unstable = inputs.nixpkgs-unstable;
  };
  modules = config.flake.modules.nixos;
  report = config.flake.fleet;
  lock = builtins.fromJSON (builtins.readFile (inputs.self + "/flake.lock"));
  lockedInput = name: lock.nodes.${lock.nodes.root.inputs.${name}};
  checkedReport =
    assert lib.assertMsg (
      builtins.match "nixos-[0-9]{2}\\.(05|11)" (lockedInput "nixpkgs-stable").original.ref != null
    ) "Stable must lock a numbered NixOS release branch, not an unstable alias.";
    assert lib.assertMsg (
      (lockedInput "nixpkgs-unstable").original.ref == "nixpkgs-unstable"
    ) "Interactive track must lock nixpkgs-unstable.";
    assert lib.assertMsg (
      builtins.attrNames expectedTracks == builtins.attrNames report
    ) "Update the explicit fleet policy oracle when adding/removing a host.";
    lib.mapAttrs (
      name: host:
      let
        system = config.flake.fleetConfigurations.${name};
      in
      assert lib.assertMsg (host.track == expectedTracks.${name}) "${name}: wrong Nixpkgs track";
      assert lib.assertMsg (
        host.nixpkgsPath == host.intendedNixpkgsPath
        && host.nixpkgsPath == toString tracks.${expectedTracks.${name}}.outPath
      ) "${name}: actual pkgs source differs from independently required input";
      assert lib.assertMsg (lib.all
        (
          message:
          lib.hasPrefix "BOOTSTRAP:" message
          || lib.hasPrefix "Neither the root account nor any wheel user has a password or SSH authorized key." message
        )
        host.failedAssertions
      ) "${name}: unexpected NixOS assertion: ${lib.concatStringsSep "; " host.failedAssertions}";
      assert lib.assertMsg (
        host.ready -> host.missing == [ ] && host.failedAssertions == [ ]
      ) "${name}: commissioned with unresolved requirements";
      host
      // {
        # Force real per-host packages, /etc/services and initrd even before the
        # final toplevel is permitted. These are evaluations, not real builds.
        components = {
          systemPath = system.config.system.path.drvPath;
          etc = system.config.system.build.etc.drvPath;
          initrd = system.config.system.build.initialRamdisk.drvPath;
        };
      }
    ) report;

  # Deliberately synthetic EVALUATION fixtures, never installable fleet members.
  # No fixture scripts are exported as provisioning packages or deploy nodes.
  allCapabilities = [
    "os-disk"
    "persistence"
    "access"
    "server"
    "vps"
    "workstation"
    "laptop"
    "gaming"
    "nas"
    "administration"
  ];
  fixtureFor =
    track: bootMode: capabilities:
    tracks.${track}.lib.nixosSystem {
      modules = [
        modules.base
      ]
      ++ map (name: modules.${name}) capabilities
      ++ [
        ({ lib, pkgs, ... }: {
          nixpkgs.hostPlatform = "x86_64-linux";
          networking.hostName = "evaluation-fixture";
          fleet = {
            bootstrap.approved = true;
            installation = {
              stateVersion = lib.versions.majorMinor pkgs.lib.version;
              hardwareReviewed = true;
              networkReviewed = true;
            };
            osDisk = {
              device = "/dev/disk/by-id/TEST-ONLY-NOT-A-REAL-DISK";
              confirmed = true;
              inherit bootMode;
              espSize = "512M";
              efiCanTouchVariables = false;
            };
            access = {
              admin = "fixture-admin";
              authorizedKeys = [ "ssh-ed25519 TEST-ONLY-NOT-A-VALID-KEY" ];
              passwordlessSudo = true;
            };
          }
          // lib.optionalAttrs (lib.elem "workstation" capabilities) {
            workstation = {
              desktopReviewed = true;
              usersReviewed = true;
            };
          }
          // lib.optionalAttrs (lib.elem "gaming" capabilities) {
            gaming.reviewed = true;
          }
          // lib.optionalAttrs (lib.elem "nas" capabilities) {
            nas.storageReviewed = true;
          }
          // lib.optionalAttrs (lib.elem "vps" capabilities) {
            vps.providerReviewed = true;
          };
        })
      ];
    };
  fixtures = lib.genAttrs (builtins.attrNames tracks) (
    track: fixtureFor track "uefi" allCapabilities
  );
  compositionReport = lib.mapAttrs (
    _: host:
    let
      fixture = fixtureFor host.track "uefi" host.capabilities;
    in
    {
      # Also check the exact shipped subsets: a combined fixture alone can mask
      # a missing dependency by supplying another capability's configuration.
      toplevel = fixture.config.system.build.toplevel.drvPath;
    }
  ) config.fleet.hosts;
  deploymentPkgs = pkgs: pkgs.extend inputs.deploy-rs.overlays.default;
  fixtureReport = lib.mapAttrs (
    track: fixture:
    let
      cfg = fixture.config;
      bios = (fixtureFor track "bios" allCapabilities).config;
      unconfirmed = fixture.extendModules {
        modules = [ { fleet.osDisk.confirmed = lib.mkForce false; } ];
      };
      partition = fixture.extendModules {
        modules = [ { fleet.osDisk.device = lib.mkForce "/dev/disk/by-id/TEST-ONLY-part1"; } ];
      };
      blank = fixture.extendModules {
        modules = [ { fleet.osDisk.device = lib.mkForce null; } ];
      };
      deployLib = (deploymentPkgs fixture.pkgs).deploy-rs.lib;
    in
    assert lib.assertMsg (cfg.fleet.bootstrap.missing == [ ]) "${track}: fixture requirements missing";
    assert lib.assertMsg (lib.all (a: a.assertion) cfg.assertions)
      "${track}: ${
        lib.concatStringsSep "; " (map (a: a.message) (lib.filter (a: !a.assertion) cfg.assertions))
      }";
    assert lib.assertMsg (
      cfg.fileSystems."/".fsType == "tmpfs"
      && cfg.fileSystems."/persist".neededForBoot
      && cfg.fileSystems."/nix".neededForBoot
    ) "${track}: ephemeral-root/early persistent mounts regressed";
    assert lib.assertMsg (
      !(builtins.tryEval unconfirmed.config.disko.devices.disk.os.device).success
    ) "Unconfirmed disko device was accepted";
    assert lib.assertMsg (
      !(builtins.tryEval partition.config.disko.devices.disk.os.device).success
    ) "Partition accepted as whole OS disk";
    assert lib.assertMsg (
      blank.config.disko.devices.disk == { }
    ) "Missing device must produce no destructive disk configuration";
    {
      toplevel = cfg.system.build.toplevel.drvPath;
      biosToplevel = bios.system.build.toplevel.drvPath;
      activation = (deployLib.activate.nixos fixture).drvPath;
      diskScript = cfg.system.build.diskoScript.drvPath;
      inherit (cfg.fleet.bootstrap) missing;
    }
  ) fixtures;
in
{
  flake.validation = {
    hosts = checkedReport;
    fixtures = fixtureReport;
    compositions = compositionReport;
  };
  perSystem = { pkgs, ... }: {
    checks = {
      # Evaluate drvPaths but do not turn their deep string contexts into build
      # dependencies. This report is data, never executable or an installation input.
      fleet-evaluation = pkgs.writeText "fleet-evaluation.json" (
        builtins.unsafeDiscardStringContext (
          builtins.toJSON {
            hosts = checkedReport;
            fixtures = fixtureReport;
            compositions = compositionReport;
          }
        )
      );
    }
    // lib.concatMapAttrs (
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
  };
}
