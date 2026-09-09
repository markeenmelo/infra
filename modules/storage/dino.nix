{
  fleet.hosts.dino.module = {
    fleet.existingStorage = {
      osDevice = "/dev/disk/by-id/nvme-BC711_NVMe_SK_hynix_512GB____FYACN05331160CP3N";
      bootMode = "uefi";
      # EFI NVRAM/fallback policy is unknown. /boot has recovered fragments and
      # a ~1 GiB FAT filesystem inside a 4 GiB partition; do NOT resize/reformat.
    };
    disko.devices.nodev = {
      "/boot" = {
        device = "/dev/disk/by-uuid/75D1-3D1A";
        fsType = "vfat";
        mountOptions = [ "umask=0077" ];
      };
      "/nix" = {
        device = "/dev/disk/by-uuid/a0082a54-1183-461f-a113-3ef1dd7aa396";
        fsType = "btrfs";
        mountOptions = [
          "subvol=nix"
          "compress=zstd"
          "noatime"
        ];
      };
      "/persist" = {
        device = "/dev/disk/by-uuid/a0082a54-1183-461f-a113-3ef1dd7aa396";
        fsType = "btrfs";
        mountOptions = [
          "subvol=persist"
          "compress=zstd"
        ];
      };
      "/home" = {
        device = "/dev/disk/by-uuid/a0082a54-1183-461f-a113-3ef1dd7aa396";
        fsType = "btrfs";
        mountOptions = [
          "subvol=home"
          "compress=zstd"
        ];
      };
    };
    fileSystems."/home".neededForBoot = true;
  };
}
