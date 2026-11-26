{
  fleet.hosts.beast.module = {
    hardware.cpu.intel.updateMicrocode = true;
    boot = {
      initrd.availableKernelModules = [
        "xhci_pci"
        "nvme"
        "usbhid"
        "usb_storage"
        "sd_mod"
      ];
      kernelModules = [ "kvm-intel" ];
    };
  };
}
