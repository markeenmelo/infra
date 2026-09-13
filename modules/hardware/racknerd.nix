{
  fleet.hosts.racknerd.module = { modulesPath, ... }: {
    # Fresh live-installer scan, 2026-09-12: KVM/SeaBIOS, five vCPUs,
    # 6,211,670,016 bytes RAM; same VirtIO disk/network and initrd modules.
    imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
    fleet.installation = {
      stateVersion = "26.05";
      hardwareReviewed = true;
      # 2026-09-12: console-verified installer key; ens3 MAC
      # 00:16:3c:ec:fa:6f, DHCPv4 address/default route/DNS without VPN.
      # The installer uses NetworkManager; the reviewed installed networkd
      # profile requests the same MAC client identifier and DHCP policy.
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
  };
}
