{
  fleet.hosts.racknerd.module =
    { config, ... }:
    {
      disko.devices.disk.os = {
        device = "/dev/disk/by-path/pci-0000:00:05.0";
        content.partitions = {
          BIOS = {
            type = "EF02";
            size = "1M";
            priority = 1;
          };
          boot = {
            type = "0700";
            priority = 2;
          };
        };
      };
      boot.loader = {
        efi.canTouchEfiVariables = false;
        limine = {
          efiSupport = false;
          biosSupport = true;
          biosDevice = config.disko.devices.disk.os.device;
        };
      };
    };
}
