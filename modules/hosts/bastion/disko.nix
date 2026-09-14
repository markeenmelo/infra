{
  fleet.hosts.bastion.module =
    { config, lib, ... }:
    {
      fleet.installation.osDevice = "/dev/disk/by-id/nvme-eui.6479a7a2ea200e8e";
      disko.devices.disk.os = {
        type = "disk";
        device = config.fleet.installation.osDevice;
        content = {
          type = "gpt";
          partitions = {
            boot = {
              type = "EF00";
              size = "2G";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            state = {
              size = "100%";
              content = {
                type = "btrfs";
                subvolumes = lib.genAttrs [ "nix" "persist" ] (name: {
                  mountpoint = "/${name}";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                });
              };
            };
          };
        };
      };
      boot.loader = {
        efi.canTouchEfiVariables = true;
        limine = {
          efiSupport = true;
          biosSupport = false;
        };
      };
    };
}
