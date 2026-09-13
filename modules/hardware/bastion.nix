{
  fleet.hosts.bastion.module = {
    fleet.installation = {
      stateVersion = "26.05";
      hardwareReviewed = true;
    };
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
