{
  fleet.hosts.bastion.module = {
    fleet.existingStorage = {
      osDevice = "/dev/disk/by-id/nvme-eui.6479a7a2ea200e8e";
      bootMode = "uefi";
      efiCanTouchVariables = true;
    };
    # OS state stays on the NVMe; tank is deliberately outside disko.
    disko.devices.nodev = {
      "/boot" = {
        device = "/dev/disk/by-uuid/418B-E89E";
        fsType = "vfat";
        mountOptions = [ "umask=0077" ];
      };
      "/nix" = {
        device = "/dev/disk/by-uuid/e56256b8-c591-497b-ad32-d4040bbb83be";
        fsType = "btrfs";
        mountOptions = [
          "subvol=nix"
          "compress=zstd"
          "noatime"
        ];
      };
      "/persist" = {
        device = "/dev/disk/by-uuid/e56256b8-c591-497b-ad32-d4040bbb83be";
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
