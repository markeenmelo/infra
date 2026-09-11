{
  fleet.hosts.racknerd.module = { modulesPath, ... }: {
    # Read-only target scan, 2026-09-09: KVM, five vCPUs, VirtIO disk/network.
    imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
    fleet.installation = {
      stateVersion = "26.05";
      hardwareReviewed = true;
      # 2026-09-10 operator attestations backed by the read-only audit:
      # provider-console login, KVM facts, uplink MAC/DNS/route without VPN.
      networkReviewed = true;
    };
    fleet.vps.providerReviewed = true;
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
