{
  fleet.hosts.racknerd.module = {
    fleet.existingStorage = {
      # Observed 100 GiB VirtIO disk with no serial/by-id. Limine only;
      # runtime mounts use UUIDs and disko has no disk/provisioning node.
      osDevice = "/dev/vda";
      bootMode = "bios";
      biosPartitionIndex = 1;
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
