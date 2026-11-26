{
  fleet.hosts.beast.module = {
    hardware = {
      cpu.intel.updateMicrocode = true;
      nvidia = {
        open = true;
        powerManagement.enable = true;
      };
    };
    services.xserver.videoDrivers = [ "nvidia" ];
    nixpkgs.config.allowUnfreePackages = [
      "nvidia-x11"
      "nvidia-settings"
    ];
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
