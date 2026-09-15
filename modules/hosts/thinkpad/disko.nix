{
  fleet.hosts.thinkpad.module =
    { config, lib, ... }:
    {
      fleet.installation.osDevice = "/dev/disk/by-id/nvme-eui.00a075013a594e93";
      disko.devices.disk.os = {
        type = "disk";
        device = config.fleet.installation.osDevice;
        content = {
          type = "gpt";
          partitions = {
            boot = {
              type = "EF00";
              size = "4G";
              priority = 1;
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            swap = {
              size = "8G";
              priority = 2;
              content.type = "swap";
            };
            state = {
              size = "100%";
              content = {
                type = "btrfs";
                subvolumes = lib.genAttrs [ "nix" "persist" "home" ] (name: {
                  mountpoint = "/${name}";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                    "nodiscard"
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
      systemd.sleep.settings.Sleep = {
        AllowHibernation = false;
        AllowHybridSleep = false;
        AllowSuspendThenHibernate = false;
      };
      fileSystems."/home".neededForBoot = true;
    };
}
