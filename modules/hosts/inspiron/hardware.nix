{
  fleet.hosts.inspiron.module =
    { pkgs, ... }:
    {
      hardware = {
        cpu.amd.updateMicrocode = true;
        firmware = [ pkgs.linux-firmware ];
      };
      boot.initrd.availableKernelModules = [
        "nvme"
        "xhci_pci"
        "ahci"
        "usb_storage"
        "sd_mod"
      ];
      boot.kernelModules = [ "kvm-amd" ];
      disko.devices.disk.os.device = "/dev/disk/by-id/nvme-BC711_NVMe_SK_hynix_512GB__FYACN05331160CP3N";
    };
}
