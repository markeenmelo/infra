{
  fleet.hosts.thinkpad.module = {
    # Read-only sysfs/lsblk (2026-09-09), privileged stdout-only scan (2026-09-10).
    # ThinkPad T14 Gen 3 (21AH00BNUS), Intel i7-1270P; i915 8086:46a6.
    fleet.installation.stateVersion = "26.05";
    boot = {
      initrd = {
        availableKernelModules = [
          "xhci_pci"
          "thunderbolt"
          "nvme"
          "usb_storage"
          "usbhid"
          "sd_mod"
        ];
        kernelModules = [ "dm-snapshot" ];
      };
      kernelModules = [ "kvm-intel" ];
    };
    hardware.enableRedistributableFirmware = true;
    hardware.cpu.intel.updateMicrocode = true;
    # Scan output is adapted, but its suppressed diagnostics still need review;
    # hardwareReviewed stays false. Do not treat the scan as a tested initrd/boot.
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
