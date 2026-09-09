{
  fleet.hosts.racknerd.module = { modulesPath, ... }: {
    # Read-only target scan, 2026-09-09: KVM, five vCPUs, VirtIO disk/network.
    imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
    fleet.installation = {
      stateVersion = "26.05";
      hardwareReviewed = true;
      # Provider console and network transition still need operator acceptance.
    };
    boot.initrd.availableKernelModules = [
      "ata_piix"
      "uhci_hcd"
      "virtio_pci"
      "sr_mod"
      "virtio_blk"
    ];
    boot.loader.limine.extraConfig = "graphics: no";
    time.timeZone = "America/Toronto";
    i18n.defaultLocale = "en_US.UTF-8";
    console.keyMap = "us";
  };
}
