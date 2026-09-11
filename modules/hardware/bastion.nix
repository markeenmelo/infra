{
  fleet.hosts.bastion.module = {
    # Read-only target scan, 2026-09-09: UGREEN DXP4800 Plus, Intel 8505.
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
