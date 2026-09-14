{
  fleet.hosts.racknerd.module = { modulesPath, ... }: {
    imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
    system.stateVersion = "26.05";
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
