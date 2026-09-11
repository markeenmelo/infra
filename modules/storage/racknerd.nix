{
  fleet.hosts.racknerd.module = {
    fleet.existingStorage = {
      # Observed 100 GiB VirtIO disk with no serial/by-id. Limine only;
      # runtime mounts use UUIDs and disko has no disk/provisioning node.
      osDevice = "/dev/vda";
      bootMode = "bios";
      biosPartitionIndex = 1;
      # 2026-09-10 operator-attested reviews over the read-only audit: ~2 GiB
      # free /boot with Limine artifacts, BIOS-boot vda1, zero Btrfs counters,
      # console fallback. Migration stance: untouched old Btrfs root subvolume
      # is the recovery fallback, as on ThinkPad; persistent state, SSH host
      # keys and the SOPS password are reconciled before activation.
      bootReviewed = true;
      migrationReviewed = true;
    };
    disko.devices.nodev = {
      "/boot" = {
        device = "/dev/disk/by-uuid/2FE0-AD99";
        fsType = "vfat";
        mountOptions = [ "umask=0077" ];
      };
      "/nix" = {
        device = "/dev/disk/by-uuid/0ccb8eeb-7ca2-4ba9-871b-e621a921ee49";
        fsType = "btrfs";
        mountOptions = [
          "subvol=nix"
          "compress=zstd"
          "noatime"
        ];
      };
      "/persist" = {
        device = "/dev/disk/by-uuid/0ccb8eeb-7ca2-4ba9-871b-e621a921ee49";
        fsType = "btrfs";
        mountOptions = [
          "subvol=persist"
          "compress=zstd"
          "noatime"
        ];
      };
    };
  };
}
