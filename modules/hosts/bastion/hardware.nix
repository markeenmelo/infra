{
  fleet.hosts.bastion.module = {
    system.stateVersion = "26.05";
    boot.initrd.availableKernelModules = [
      "xhci_pci"
      "nvme"
      "ahci"
      "sd_mod"
    ];
    hardware.enableRedistributableFirmware = true;
    hardware.cpu.intel.updateMicrocode = true;
    boot.loader.limine.extraConfig = "graphics: no";
  };
}
