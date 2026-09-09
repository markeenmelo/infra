{
  fleet.hosts.thinkpad.module = {
    # Read-only sysfs/lsblk + previous installation source, 2026-09-09.
    # ThinkPad T14 Gen 3 (21AH00BNUS), Intel i7-1270P; i915 8086:46a6.
    fleet.installation.stateVersion = "26.05";
    boot.initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "thunderbolt"
    ];
    hardware.enableRedistributableFirmware = true;
    hardware.cpu.intel.updateMicrocode = true;
    # Hardware scan needs privileged completion; hardwareReviewed stays false.
    # modules/kernel.nix selects the requested stock 7.x kernel. Retain native
    # i915 probing for Alder Lake-P, not experimental xe/force_probe overrides;
    # never load a disconnected eGPU's unverified driver.
    services.thermald.enable = true;
    services.hardware.bolt.enable = true;
    environment.persistence."/persist".directories = [ "/var/lib/boltd" ];
    networking.networkmanager.wifi.powersave = true;
    fleet.workstation.homePersistence = "filesystem";
    users.users.marcos.extraGroups = [ "networkmanager" ];
    time.timeZone = "America/Toronto";
    i18n.defaultLocale = "en_US.UTF-8";
    console.keyMap = "us";
  };
}
