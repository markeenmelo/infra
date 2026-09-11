{ inputs, ... }:
{
  # Adoption of installed systems is NOT the fresh-disk os-disk capability.
  flake.modules.nixos.existing-storage =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib) mkOption types;
      cfg = config.fleet.existingStorage;
      blockedOutputs = builtins.attrNames (config.disko.devices._scripts { inherit pkgs; }) ++ [
        "disko"
        "diskoNoDeps"
        "installTest"
        "vmWithDisko"
        "diskoImages"
        "diskoImagesScript"
      ];
    in
    {
      imports = [ inputs.disko.nixosModules.disko ];
      options.fleet.existingStorage = {
        osDevice = mkOption {
          type = types.nullOr (types.strMatching "/dev/(disk/by-id/[a-zA-Z0-9._:+-]+|vda)");
          default = null;
          apply =
            device:
            assert lib.assertMsg (
              device == null || builtins.match ".*-part[0-9]+" device == null
            ) "Existing OS identity must be a whole disk, not a partition.";
            device;
          description = "Observed OS disk, inventory/BIOS bootloader only, NEVER a provisioning target. /dev/vda is the reviewed no-serial VPS exception.";
        };
        bootMode = mkOption {
          type = types.nullOr (
            types.enum [
              "uefi"
              "bios"
            ]
          );
          default = null;
          description = "Observed firmware boot mode.";
        };
        efiCanTouchVariables = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Explicit Limine EFI NVRAM policy; false requires verified fallback boot.";
        };
        biosPartitionIndex = mkOption {
          type = types.nullOr types.ints.positive;
          default = null;
          description = "Observed dedicated Limine BIOS second-stage partition, when applicable.";
        };
        bootReviewed = mkOption {
          type = types.bool;
          default = false;
          description = "Boot filesystem health/capacity, firmware entry, BIOS device and independent recovery reviewed for this transition.";
        };
        migrationReviewed = mkOption {
          type = types.bool;
          default = false;
          description = "Backups/restore, mount identities, persistent state and credential migration reviewed before switching to this baseline.";
        };
      };
      config = {
        fleet.bootstrap.missing =
          lib.optional (
            cfg.osDevice == null
          ) "Record the existing OS disk identity (not provisioning approval)."
          ++ lib.optional (cfg.bootMode == null) "Record the existing firmware boot mode."
          ++ lib.optional (
            cfg.bootMode == "uefi" && cfg.efiCanTouchVariables == null
          ) "Choose the existing installation's Limine EFI NVRAM/fallback policy."
          ++
            lib.optional (!cfg.bootReviewed)
              "Review existing /boot health/capacity, Limine and console recovery; acknowledge fleet.existingStorage.bootReviewed."
          ++
            lib.optional (!cfg.migrationReviewed)
              "Review backups/restore and migrate credentials/persistent state before activation; acknowledge fleet.existingStorage.migrationReviewed.";

        assertions = [
          {
            assertion = cfg.osDevice != "/dev/vda" || config.networking.hostName == "racknerd";
            message = "The no-serial /dev/vda bootloader exception is specific to racknerd.";
          }
        ];

        # Mount-only nodev descriptions derive fileSystems but cannot format a
        # disk, create an LV, or create/import a data pool through disko.
        disko.devices = {
          bcachefs_filesystems = lib.mkForce { };
          disk = lib.mkForce { };
          lvm_vg = lib.mkForce { };
          mdadm = lib.mkForce { };
          zpool = lib.mkForce { };
        };
        # Even an empty legacy destroy script may unmount /mnt. Block all public
        # script/image aliases, including direct builds on an approved host.
        system.build = lib.genAttrs blockedOutputs (
          name:
          lib.mkForce (
            throw "Existing installation: ${name} is disabled. This fleet has no provisioning plan; see docs/hosts.md."
          )
        );
        boot.loader = {
          grub.enable = false;
          systemd-boot.enable = false;
          timeout = 5;
          efi.canTouchEfiVariables = cfg.efiCanTouchVariables == true;
          limine = {
            enable = cfg.bootMode != null;
            efiSupport = cfg.bootMode == "uefi";
            biosSupport = cfg.bootMode == "bios";
            biosDevice = if cfg.bootMode == "bios" && cfg.osDevice != null then cfg.osDevice else "nodev";
            partitionIndex = cfg.biosPartitionIndex;
            enableEditor = false;
            force = false;
            validateChecksums = true;
            panicOnChecksumMismatch = true;
            enrollConfig = false;
            maxGenerations = 10;
            style.wallpapers = [ ];
          };
        };
        fileSystems = {
          "/persist".neededForBoot = true;
          "/nix".neededForBoot = true;
        };
      };
    };
}
