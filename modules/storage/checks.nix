{ config, lib, ... }:
let
  inherit (config.fleet.validation) fixtureFor fixtures allCapabilities;
  foreignDiskoDevices = {
    disk.TEST-ONLY-FOREIGN = {
      type = "disk";
      device = "/dev/disk/by-id/TEST-ONLY-FOREIGN";
    };
    lvm_vg.TEST-ONLY-FOREIGN = {
      type = "lvm_vg";
      lvs.unwanted = {
        size = "1M";
        content = {
          type = "filesystem";
          format = "ext4";
        };
      };
    };
    mdadm.TEST-ONLY-FOREIGN.type = "mdadm";
    zpool.TEST-ONLY-FOREIGN.type = "zpool";
    bcachefs_filesystems.TEST-ONLY-FOREIGN.type = "bcachefs_filesystem";
  };
  unusedDiskoCollections = [
    "bcachefs_filesystems"
    "lvm_vg"
    "mdadm"
    "zpool"
  ];
  existingReport = lib.genAttrs (builtins.attrNames fixtures) (
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
          modules = [ { disko.devices = foreignDiskoDevices; } ];
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
      && lib.all (collection: injected.disko.devices.${collection} == { }) unusedDiskoCollections
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
  fixtureReport = lib.mapAttrs (
    track: fixture:
    let
      cfg = fixture.config;
      injected =
        (fixture.extendModules {
          modules = [ { disko.devices = foreignDiskoDevices; } ];
        }).config;
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
    assert lib.assertMsg (
      builtins.attrNames injected.disko.devices.disk == [ "os" ]
      && lib.all (collection: injected.disko.devices.${collection} == { }) unusedDiskoCollections
      && injected.system.build.diskoScript.drvPath == cfg.system.build.diskoScript.drvPath
    ) "${track}: foreign storage contributions changed the OS-only disko script";
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
    {
      inherit espSizes;
      toplevel = cfg.system.build.toplevel.drvPath;
      biosToplevel = bios.system.build.toplevel.drvPath;
      diskScript = cfg.system.build.diskoScript.drvPath;
      foreignStorageExcluded = true;
      inherit (cfg.fleet.bootstrap) missing;
    }
  ) fixtures;
in
{
  fleet.validation.hostChecks.storage =
    {
      name,
      host,
      system,
    }:
    let
      cfg = system.config;
    in
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
    true;
  flake.validation = {
    existingInstallations = existingReport;
    fixtures = fixtureReport;
  };
  # Synthetic evaluation-only facts; never part of fleet.hosts.
  fleet.validation.fixtureModules = {
    os-disk = bootMode: {
      fleet.osDisk = {
        device = "/dev/disk/by-id/TEST-ONLY-NOT-A-REAL-DISK";
        confirmed = true;
        inherit bootMode;
        espSize = if bootMode == "uefi" then "512M" else null;
        efiCanTouchVariables = false;
      };
    };
    existing-storage = bootMode: {
      fleet.existingStorage = {
        osDevice = "/dev/disk/by-id/TEST-ONLY-NOT-A-REAL-DISK";
        inherit bootMode;
        efiCanTouchVariables = false;
        biosPartitionIndex = if bootMode == "bios" then 1 else null;
        bootReviewed = true;
        migrationReviewed = true;
      };
      disko.devices.nodev = {
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
    };
    nas = _: { fleet.nas.storageReviewed = true; };
  };
}
