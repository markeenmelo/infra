{
  fleet.hosts.thinkpad.module = {
    # Read-only sysfs/lsblk (2026-09-09), privileged stdout-only scan (2026-09-10).
    # ThinkPad T14 Gen 3 (21AH00BNUS), Intel i7-1270P; i915 8086:46a6.
    fleet.installation = {
      stateVersion = "26.05";
      hardwareReviewed = true;
    };
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
    # Both privileged scans are reviewed. The 15 subvolume diagnostics are the
    # scanner's bind-mount fallback, verified against installed/pinned source.
    # Retain USB/SCSI support observed in the earlier scan; no initrd/boot test.
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
