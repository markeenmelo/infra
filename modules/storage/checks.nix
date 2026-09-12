{ config, lib, ... }:
let
  inherit (config.fleet.validation) fixtureFor fixtures allCapabilities;
  hosts = [
    "bastion"
    "racknerd"
    "thinkpad"
  ];
  unused = [
    "bcachefs_filesystems"
    "lvm_vg"
    "mdadm"
    "zpool"
  ];
  scriptNames =
    system:
    builtins.attrNames (system.config.disko.devices._scripts { inherit (system) pkgs; })
    ++ [
      "disko"
      "diskoNoDeps"
      "installTest"
      "vmWithDisko"
      "diskoImages"
      "diskoImagesScript"
    ];
  rejectsScripts =
    system:
    lib.all (name: !(builtins.tryEval system.config.system.build.${name}.drvPath).success) (
      scriptNames system
    );
  layouts = lib.genAttrs [ "stable" "unstable" ] (
    track:
    lib.genAttrs hosts (
      name:
      let
        fixture =
          if name == "bastion" then
            fixtures.${track}
          else
            fixtureFor track (if name == "racknerd" then "bios" else "uefi") (
              [ "${name}-disko" ] ++ lib.filter (c: c != "bastion-disko") allCapabilities
            );
        cfg = fixture.config;
        parts = cfg.disko.devices.disk.os.content.partitions;
        changed = module: fixture.extendModules { modules = [ module ]; };
        pending = changed { fleet.bootstrap.approved = lib.mkForce false; };
        unreviewed = changed { fleet.installation.storageReviewed = lib.mkForce false; };
        missing = changed { fleet.installation.osDevice = lib.mkForce null; };
        partition = changed {
          fleet.installation.osDevice = lib.mkForce "/dev/disk/by-id/TEST-ONLY-part1";
        };
        redirected = changed {
          disko.devices.disk.os.device = lib.mkForce "/dev/disk/by-id/TEST-ONLY-FOREIGN";
        };
        foreign = changed {
          disko.devices = {
            disk.TEST-ONLY-FOREIGN = {
              type = "disk";
              device = "/dev/disk/by-id/TEST-ONLY-FOREIGN";
              content = {
                type = "gpt";
                partitions.data = {
                  size = "100%";
                  content = {
                    type = "filesystem";
                    format = "ext4";
                    mountpoint = "/TEST-ONLY-FOREIGN";
                  };
                };
              };
            };
            lvm_vg.TEST-ONLY-FOREIGN.type = "lvm_vg";
            mdadm.TEST-ONLY-FOREIGN.type = "mdadm";
            zpool.TEST-ONLY-FOREIGN.type = "zpool";
            bcachefs_filesystems.TEST-ONLY-FOREIGN.type = "bcachefs_filesystem";
          };
        };
      in
      assert lib.assertMsg (
        cfg.fleet.bootstrap.missing == [ ] && lib.all (a: a.assertion) cfg.assertions
      ) "${track}/${name}: fresh-layout fixture failed";
      assert lib.assertMsg (
        builtins.attrNames cfg.disko.devices.disk == [ "os" ]
        && lib.all (
          collection:
          cfg.disko.devices.${collection} == { } && foreign.config.disko.devices.${collection} == { }
        ) unused
        && cfg.disko.devices.disk.os.device == "/dev/disk/by-id/TEST-ONLY-NOT-A-REAL-DISK"
        && cfg.disko.devices.disk.os.content.type == "gpt"
        && parts.boot.size == (if name == "thinkpad" then "4G" else "2G")
        && parts.boot.type == (if name == "racknerd" then "0700" else "EF00")
        && parts.state.size == "100%"
        && parts.state.content.type == "btrfs"
        && cfg.fileSystems."/".fsType == "tmpfs"
        && cfg.fileSystems."/nix".neededForBoot
        && cfg.fileSystems."/persist".neededForBoot
        && lib.elem "subvol=nix" cfg.fileSystems."/nix".options
        && lib.elem "subvol=persist" cfg.fileSystems."/persist".options
        && cfg.fileSystems."/boot".fsType == "vfat"
        && lib.elem "umask=0077" cfg.fileSystems."/boot".options
        && cfg.boot.initrd.luks.devices == { }
        && !cfg.boot.initrd.services.lvm.enable
        && cfg.boot.resumeDevice == ""
        && cfg.boot.loader.limine.enable
        && !cfg.boot.loader.grub.enable
        && !cfg.boot.loader.systemd-boot.enable
        && !cfg.boot.loader.limine.force
        && !cfg.boot.loader.limine.enableEditor
        && cfg.boot.loader.limine.validateChecksums
        && cfg.boot.loader.limine.panicOnChecksumMismatch
        && !cfg.boot.loader.limine.enrollConfig
        && cfg.boot.loader.limine.maxGenerations == 10
        && cfg.boot.loader.limine.style.wallpapers == [ ]
        && cfg.boot.loader.limine.biosSupport == (name == "racknerd")
        && cfg.boot.loader.limine.efiSupport == (name != "racknerd")
      ) "${track}/${name}: plain OS layout or Limine policy regressed";
      assert lib.assertMsg (
        if name == "racknerd" then
          parts.BIOS.type == "EF02"
          && parts.BIOS.size == "1M"
          && parts.BIOS._index == 1
          && parts.boot._index == 2
          && cfg.boot.loader.limine.partitionIndex == 1
          && cfg.boot.loader.limine.biosDevice == cfg.fleet.installation.osDevice
        else
          parts.boot._index == 1
      ) "${track}/${name}: boot partition ordering regressed";
      assert lib.assertMsg (
        if name == "thinkpad" then
          cfg.fileSystems."/home".neededForBoot
          && cfg.fileSystems."/home".fsType == "btrfs"
          && lib.elem "subvol=home" cfg.fileSystems."/home".options
          && !(lib.elem "/home" (map (d: d.dirPath) cfg.environment.persistence."/persist".directories))
          && parts.swap.size == "8G"
          && parts.swap.type == "8200"
          && parts.boot._index < parts.swap._index
          && parts.swap._index < parts.state._index
          && !parts.swap.content.randomEncryption
          && !parts.swap.content.resumeDevice
          && map (s: s.device) cfg.swapDevices == [ parts.swap.device ]
          && cfg.systemd.sleep.settings.Sleep.AllowHibernation == false
          && cfg.systemd.sleep.settings.Sleep.AllowHybridSleep == false
          && cfg.systemd.sleep.settings.Sleep.AllowSuspendThenHibernate == false
        else
          cfg.swapDevices == [ ] && !(cfg.fileSystems ? "/home")
      ) "${track}/${name}: home/swap/hibernation policy regressed";
      assert lib.all rejectsScripts [
        pending
        unreviewed
        missing
        partition
        redirected
        foreign
      ];
      assert !(builtins.tryEval unreviewed.config.system.build.toplevel.drvPath).success;
      assert
        !(builtins.tryEval
          (changed { fleet.installation.osDevice = lib.mkForce "/dev/vda"; })
          .config.fleet.installation.osDevice
        ).success;
      {
        toplevel = cfg.system.build.toplevel.drvPath;
        bootloader = cfg.system.build.installBootLoader.drvPath;
        diskScript = cfg.system.build.diskoScript.drvPath;
        pendingScriptsBlocked = true;
        foreignStorageBlocked = true;
      }
    )
  );
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
      !host.ready
      && !cfg.fleet.installation.storageReviewed
      && host.storageMode == "provision"
      && builtins.attrNames cfg.disko.devices.disk == [ "os" ]
      && lib.all (collection: cfg.disko.devices.${collection} == { }) unused
      && cfg.fileSystems."/".fsType == "tmpfs"
      && cfg.fileSystems."/nix".neededForBoot
      && cfg.fileSystems."/persist".neededForBoot
      && cfg.boot.initrd.luks.devices == { }
      && !cfg.boot.initrd.services.lvm.enable
      && cfg.boot.loader.limine.enable
      && !cfg.boot.loader.grub.enable
      && !cfg.boot.loader.systemd-boot.enable
      && (name != "racknerd" || host.osDisk == null)
      && rejectsScripts system
    ) "${name}: fresh candidates must remain unready with provisioning blocked pending review";
    true;

  flake.validation = {
    storageLayouts =
      assert builtins.attrNames config.flake.nixosConfigurations == [ ];
      assert builtins.attrNames config.flake.deploy.nodes == [ ];
      layouts;
    fixtures = lib.mapAttrs (_: fixture: {
      toplevel = fixture.config.system.build.toplevel.drvPath;
      diskScript = fixture.config.system.build.diskoScript.drvPath;
      missing = fixture.config.fleet.bootstrap.missing;
    }) fixtures;
  };
  fleet.validation.fixtureModules =
    (lib.genAttrs (map (name: "${name}-disko") hosts) (
      _: _: {
        # Synthetic evaluation only: never imported into fleet.hosts.
        fleet.installation = {
          osDevice = "/dev/disk/by-id/TEST-ONLY-NOT-A-REAL-DISK";
          storageReviewed = true;
        };
      }
    ))
    // {
      nas = _: { fleet.nas.storageReviewed = true; };
    };
}
