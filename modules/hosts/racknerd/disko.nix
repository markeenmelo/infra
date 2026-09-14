{
  fleet.hosts.racknerd.module =
    { config, lib, ... }:
    {
      fleet.installation.osDevice = "/dev/disk/by-path/pci-0000:00:04.0";
      disko.devices.disk.os = {
        type = "disk";
        device = config.fleet.installation.osDevice;
        content = {
          type = "gpt";
          partitions = {
            BIOS = {
              type = "EF02";
              size = "1M";
              priority = 1;
            };
            boot = {
              type = "0700";
              size = "2G";
              priority = 2;
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
      boot.loader.limine = {
        efiSupport = false;
        biosSupport = true;
        biosDevice = config.fleet.installation.osDevice;
        partitionIndex = 1;
      };
    };
}
