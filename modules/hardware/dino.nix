{
  fleet.hosts.dino.module = {
    # Read-only target scan, 2026-09-09: Dell Inspiron 14 7425 2-in-1,
    # Ryzen 7 5825U; amdgpu 1002:15e7, Intel Wi-Fi 8086:2725.
    fleet = {
      installation = {
        # Running release is NOT evidence of the original stateVersion.
        stateVersion = null;
        hardwareReviewed = true;
      };
      persistence.rootSize = "2G";
      workstation.homePersistence = "filesystem";
    };
    boot.initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "ahci"
    ];
    hardware.enableRedistributableFirmware = true;
    hardware.cpu.amd.updateMicrocode = true;
    # Retain the observed zram policy; do not invent a swap partition/hibernate.
    zramSwap = {
      enable = true;
      memoryPercent = 50;
    };
    # Preserve the existing non-admin user and UID; passwords need secure
    # migration before activation. No gaming software or extra wheel membership.
    users.users.ian = {
      isNormalUser = true;
      uid = 1001;
      hashedPasswordFile = "/persist/secrets/ian-password-hash";
    };
    users.users.marcos.extraGroups = [ "networkmanager" ];
    time.timeZone = "America/Toronto";
    i18n.defaultLocale = "en_US.UTF-8";
    console.keyMap = "us";
  };
}
