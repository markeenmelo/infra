{
  fleet.hosts.thinkpad.module = {
    fleet.existingStorage = {
      osDevice = "/dev/disk/by-id/nvme-eui.00a075013a594e93";
      bootMode = "uefi";
      efiCanTouchVariables = true; # Preserve the verified existing NVRAM policy.
      # 2026-09-10: active/first EFI entry matches this ESP and Limine; capacity,
      # health metadata and operator-confirmed console/rescue recovery reviewed.
      # This is preflight, not a new boot test or storage-operation permission.
      bootReviewed = true;
      # 2026-09-10: operator accepted the no-new-backup stance (preserved old
      # root and Limine generations, verified console/rescue, tested independent
      # SOPS recovery, untouched /home), chose first-boot regeneration of
      # CUPS/clock/power-profile state, and corrected the AccountsService
      # backing mode (verified 700 root:root on the bound subvolume path).
      # Recorded review; the two-boot acceptance remains.
      migrationReviewed = true;
    };
    # Preserve the existing LUKS2 container, mapper name, LVM and swap. No
    # formatting definition or passphrase/key input is part of the Nix store.
    boot = {
      initrd.luks.devices.crypted = {
        device = "/dev/disk/by-uuid/072d4bf0-1930-4203-a5ec-1430e2e67c71";
        # Deliberate preservation of the current discard-capable mapping.
        allowDiscards = true;
      };
      initrd.services.lvm.enable = true;
      resumeDevice = "/dev/vg/swap";
    };
    swapDevices = [ { device = "/dev/disk/by-uuid/df87ed65-251d-4e5a-8451-f7df56f2819c"; } ];
    disko.devices.nodev = {
      "/boot" = {
        device = "/dev/disk/by-uuid/E0BE-02B0";
        fsType = "vfat";
        mountOptions = [ "umask=0077" ];
      };
      "/nix" = {
        device = "/dev/mapper/vg-system";
        fsType = "btrfs";
        mountOptions = [
          "subvol=nix"
          "compress=zstd"
          "noatime"
          "nodiscard"
          "x-systemd.device-timeout=infinity"
        ];
      };
      "/persist" = {
        device = "/dev/mapper/vg-system";
        fsType = "btrfs";
        mountOptions = [
          "subvol=persist"
          "compress=zstd"
          "noatime"
          "nodiscard"
          "x-systemd.device-timeout=infinity"
        ];
      };
      "/home" = {
        device = "/dev/mapper/vg-system";
        fsType = "btrfs";
        mountOptions = [
          "subvol=home"
          "compress=zstd"
          "noatime"
          "nodiscard"
          "x-systemd.device-timeout=infinity"
        ];
      };
    };
    fileSystems."/home".neededForBoot = true;
    fleet.workstation.homePersistence = "filesystem";
    # Old Btrfs root is left intact; no root-reset/deletion hook is carried over.
  };
}
