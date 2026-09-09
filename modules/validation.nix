{
  config,
  inputs,
  lib,
  options,
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
        cfg = system.config;
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
      assert lib.assertMsg (
        host.storageMode == "existing"
        && cfg.disko.devices.disk == { }
        && cfg.disko.devices.zpool == { }
        && cfg.fileSystems."/".fsType == "tmpfs"
        && cfg.fileSystems."/nix".neededForBoot
        && cfg.fileSystems."/persist".neededForBoot
        && cfg.boot.loader.limine.enable
        && !cfg.boot.loader.limine.force
        && !cfg.boot.loader.grub.enable
        && !cfg.boot.loader.systemd-boot.enable
      ) "${name}: real hosts must preserve existing storage and use Limine";
      assert lib.all
        (
          output:
          lib.assertMsg (
            !(builtins.tryEval cfg.system.build.${output}.drvPath).success
          ) "${name}: real host exposed provisioning output ${output}"
        )
        [
          "diskoScript"
          "destroyFormatMount"
          "format"
          "mount"
          "diskoImages"
        ];
      assert lib.assertMsg (
        !cfg.services.tailscale.enable
        && !cfg.services.xserver.enable
        && !cfg.services.displayManager.enable
        && !cfg.services.greetd.enable
        && !cfg.programs.steam.enable
        && cfg.systemd.enableEmergencyMode
        && cfg.services.openssh.settings.PermitRootLogin == "no"
        && cfg.services.openssh.settings.AllowUsers == [ "marcos" ]
        && cfg.security.sudo.wheelNeedsPassword
        && !cfg.fleet.access.passwordlessSudo
        && cfg.networking.firewall.allowedTCPPorts == [ 22 ]
        && cfg.networking.firewall.allowedUDPPorts == [ ]
      ) "${name}: headless SSH-only baseline or recovery policy regressed";
      assert lib.assertMsg (
        cfg.sops.age.keyFile == cfg.fleet.secrets.ageKeyFile
        && !cfg.sops.age.generateKey
        && cfg.sops.age.sshKeyPaths == [ ]
        && cfg.sops.gnupg.sshKeyPaths == [ ]
        && cfg.sops.validateSopsFiles
        && !cfg.sops.useTmpfs
        && cfg.fleet.access.passwordSecrets ? marcos
        && (
          name != "thinkpad"
          || (
            cfg.fleet.access.passwordSecrets.marcos == "marcos-password-hash"
            && cfg.users.users.marcos.hashedPasswordFile == cfg.sops.secrets.marcos-password-hash.path
            && cfg.sops.secrets.marcos-password-hash.neededForUsers
            && builtins.attrNames cfg.sops.secrets == [ "marcos-password-hash" ]
          )
        )
      ) "${name}: SOPS identity/password policy regressed or unrelated secrets enabled";
      assert lib.assertMsg (
        (lib.elem name [
          "thinkpad"
          "dino"
        ])
        -> (
          cfg.fileSystems."/home".neededForBoot
          && !(lib.elem "/home" host.persistence.directories)
          && cfg.services.power-profiles-daemon.enable
        )
      ) "${name}: preserve laptop home mounts and power management";
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
    "headless"
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
          }
          // lib.optionalAttrs (lib.elem "os-disk" capabilities) {
            osDisk = {
              device = "/dev/disk/by-id/TEST-ONLY-NOT-A-REAL-DISK";
              confirmed = true;
              inherit bootMode;
              espSize = if bootMode == "uefi" then "512M" else null;
              efiCanTouchVariables = false;
            };
          }
          // lib.optionalAttrs (lib.elem "existing-storage" capabilities) {
            existingStorage = {
              osDevice = "/dev/disk/by-id/TEST-ONLY-NOT-A-REAL-DISK";
              inherit bootMode;
              efiCanTouchVariables = false;
              biosPartitionIndex = if bootMode == "bios" then 1 else null;
              bootReviewed = true;
              migrationReviewed = true;
            };
          }
          // lib.optionalAttrs (lib.elem "workstation" capabilities) {
            workstation.usersReviewed = true;
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
          # Parse the shipped ciphertext with a synthetic consumer. There is no
          # matching fixture identity, decryption, install or exported target.
          sops.secrets.TEST-ONLY-password = {
            sopsFile = ../secrets/hosts/thinkpad.yaml;
            key = "marcos-password-hash";
            neededForUsers = true;
          };
          disko.devices.nodev = lib.optionalAttrs (lib.elem "existing-storage" capabilities) {
            "/boot" = {
              device = "/dev/disk/by-uuid/TEST-ONLY-ESP";
              fsType = "vfat";
              mountOptions = [ "umask=0077" ];
            };
            "/nix" = {
              device = "/dev/disk/by-uuid/TEST-ONLY-STATE";
              fsType = "btrfs";
              mountOptions = [ "subvol=nix" ];
            };
            "/persist" = {
              device = "/dev/disk/by-uuid/TEST-ONLY-STATE";
              fsType = "btrfs";
              mountOptions = [ "subvol=persist" ];
            };
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
  existingReport = lib.genAttrs (builtins.attrNames tracks) (
    track:
    let
      capabilities = [ "existing-storage" ] ++ lib.filter (name: name != "os-disk") allCapabilities;
      fixture = fixtureFor track "uefi" capabilities;
      cfg = fixture.config;
      bios = (fixtureFor track "bios" capabilities).config;
      pending = fixture.extendModules {
        modules = [
          {
            fleet = {
              bootstrap.approved = lib.mkForce false;
              existingStorage.bootReviewed = lib.mkForce false;
              existingStorage.migrationReviewed = lib.mkForce false;
            };
          }
        ];
      };
      missingReview = fixture.extendModules {
        modules = [
          {
            fleet.existingStorage.migrationReviewed = lib.mkForce false;
          }
        ];
      };
      home =
        (fixture.extendModules {
          modules = [
            {
              fleet.workstation.homePersistence = "filesystem";
              disko.devices.nodev."/home" = {
                device = "/dev/disk/by-uuid/TEST-ONLY-STATE";
                fsType = "btrfs";
                mountOptions = [ "subvol=home" ];
              };
              fileSystems."/home".neededForBoot = true;
            }
          ];
        }).config;
      injected =
        (fixture.extendModules {
          modules = [
            {
              disko.devices.disk.unwanted = {
                type = "disk";
                device = "/dev/disk/by-id/TEST-ONLY-DATA";
              };
            }
          ];
        }).config;
      scriptNames = builtins.attrNames (cfg.disko.devices._scripts { inherit (fixture) pkgs; }) ++ [
        "disko"
        "diskoNoDeps"
        "installTest"
        "vmWithDisko"
        "diskoImages"
        "diskoImagesScript"
      ];
    in
    assert lib.assertMsg (
      cfg.fleet.bootstrap.missing == [ ] && lib.all (a: a.assertion) cfg.assertions
    ) "${track}: existing-installation fixture failed";
    assert lib.assertMsg (
      cfg.fileSystems."/".fsType == "tmpfs"
      && cfg.fileSystems."/nix".neededForBoot
      && cfg.fileSystems."/persist".neededForBoot
      && cfg.fileSystems."/nix".device == "/dev/disk/by-uuid/TEST-ONLY-STATE"
      && lib.elem "subvol=persist" cfg.fileSystems."/persist".options
    ) "${track}: existing mounts must retain identities and early persistence";
    assert lib.assertMsg (
      injected.disko.devices.disk == { }
      && cfg.disko.devices.zpool == { }
      && cfg.disko.devices.lvm_vg == { }
      && cfg.disko.devices.mdadm == { }
    ) "${track}: existing installs must not expose destructive device nodes";
    assert lib.all (
      name:
      lib.assertMsg (
        !(builtins.tryEval cfg.system.build.${name}.drvPath).success
        && !(builtins.tryEval pending.config.system.build.${name}.drvPath).success
      ) "${track}: existing install exposed ${name}"
    ) scriptNames;
    assert lib.assertMsg (
      !(builtins.tryEval missingReview.config.system.build.toplevel.drvPath).success
    ) "${track}: ready alone must not bypass migration review";
    assert lib.assertMsg (
      cfg.boot.loader.limine.enable
      && cfg.boot.loader.limine.efiSupport
      && !cfg.boot.loader.limine.biosSupport
      && !cfg.boot.loader.limine.enableEditor
      && !cfg.boot.loader.limine.force
      && cfg.boot.loader.limine.validateChecksums
      && !cfg.boot.loader.grub.enable
      && !cfg.boot.loader.systemd-boot.enable
      && bios.boot.loader.limine.biosSupport
      && !bios.boot.loader.limine.efiSupport
      && bios.boot.loader.limine.partitionIndex == 1
      && bios.fileSystems."/boot".fsType == "vfat"
    ) "${track}: Limine EFI/BIOS policy regressed";
    assert lib.assertMsg (
      !(lib.elem "/home" (map (d: d.dirPath) home.environment.persistence."/persist".directories))
      && home.fileSystems."/home".neededForBoot
    ) "${track}: separate /home must not also be an impermanence bind";
    assert lib.assertMsg (
      cfg.services.openssh.settings.PermitRootLogin == "no"
      && cfg.services.openssh.settings.AuthenticationMethods == "publickey"
      && cfg.services.openssh.settings.AllowUsers == [ "fixture-admin" ]
      && cfg.networking.firewall.allowedTCPPorts == [ 22 ]
      && cfg.networking.firewall.allowedUDPPorts == [ ]
      && cfg.services.fail2ban.enable
      && cfg.services.fail2ban.banaction == "nftables-multiport"
      && lib.elem "/var/lib/fail2ban" (
        map (d: d.dirPath) cfg.environment.persistence."/persist".directories
      )
      && cfg.services.fail2ban.jails.DEFAULT.settings.backend == "systemd"
      && !cfg.fleet.access.passwordlessSudo
      && cfg.security.sudo.wheelNeedsPassword
      && cfg.users.users.fixture-admin.hashedPasswordFile == "/run/secrets-for-users/TEST-ONLY-password"
      && cfg.nix.settings.trusted-users == [ "root" ]
      && cfg.services.power-profiles-daemon.enable
      && !cfg.services.tlp.enable
      && !cfg.services.xserver.enable
      && !cfg.services.tailscale.enable
      && !cfg.programs.steam.enable
      && cfg.systemd.enableEmergencyMode
    ) "${track}: headless security/power/recovery baseline regressed";
    {
      toplevel = cfg.system.build.toplevel.drvPath;
      biosToplevel = bios.system.build.toplevel.drvPath;
      homeToplevel = home.system.build.toplevel.drvPath;
      bootloader = cfg.system.build.installBootLoader.drvPath;
      inherit scriptNames;
      provisioningBlocked = true;
      migrationReviewRequired = true;
    }
  );
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
      withEspSize =
        espSize:
        (fixture.extendModules {
          modules = [ { fleet.osDisk.espSize = lib.mkForce espSize; } ];
        }).config;
      missingEsp = withEspSize null;
      espSizes = {
        accepted = [
          "512M"
          "513M"
          "1024M"
          "1G"
          "2G"
        ];
        rejected = [
          "1M"
          "511M"
          "0M"
          "0G"
          "512"
          "512MB"
          "512MiB"
          "512m"
          "1.5G"
        ];
      };
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
    # Force the actual script derivation, not just the declared option type:
    # NixOS toplevel assertions alone do not guard direct disko evaluation.
    assert lib.all (
      size:
      lib.assertMsg (
        !(builtins.tryEval (withEspSize size).system.build.diskoScript.drvPath).success
      ) "${track}: invalid/undersized ESP '${size}' allowed a disko script"
    ) espSizes.rejected;
    assert lib.all (
      size:
      let
        sized = withEspSize size;
      in
      lib.assertMsg (
        sized.disko.devices.disk.os.content.partitions.ESP.size == size
        && sized.fleet.bootstrap.missing == [ ]
        && builtins.isString sized.system.build.diskoScript.drvPath
      ) "${track}: valid ESP '${size}' was rejected or altered"
    ) espSizes.accepted;
    assert lib.assertMsg (
      missingEsp.fleet.osDisk.espSize == null
      && missingEsp.disko.devices.disk == { }
      && lib.elem "Size fleet.osDisk.espSize explicitly." missingEsp.fleet.bootstrap.missing
    ) "${track}: missing ESP size must remain a blocker with no destructive disk configuration";
    assert lib.assertMsg (
      bios.fleet.osDisk.espSize == null
      && !(bios.disko.devices.disk.os.content.partitions ? ESP)
      && bios.fleet.bootstrap.missing == [ ]
    ) "${track}: BIOS must not require or create an ESP";
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
      inherit espSizes;
      deploymentAccess = {
        nonRootToplevel = deployAdmin.config.system.build.toplevel.drvPath;
        rootRejected = true;
        nullBlocked = true;
        unknownUserRejected = true;
      };
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
    existingInstallations = existingReport;
    sops = sopsReport;
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
            existingInstallations = existingReport;
            sops = sopsReport;
          }
        )
      );
    }
    // lib.mapAttrs' (
      track: fixture:
      lib.nameValuePair "${track}-sops-users-manifest" fixture.config.system.build.sops-nix-users-manifest
    ) fixtures
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
