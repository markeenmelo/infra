{
  fleet.hosts.edge.module = {
    disko.devices.disk.os = {
      device = "/dev/disk/by-path/pci-0000:18:00.0-scsi-0:0:0:1";
      content.partitions.state.content.extraFormatArgs = [
        "--pbkdf-memory"
        "524288"
      ];
    };
    boot.loader.efi.canTouchEfiVariables = false;
  };
}
