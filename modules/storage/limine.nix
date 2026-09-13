{
  flake.modules.nixos.limine = {
    boot.loader = {
      grub.enable = false;
      systemd-boot.enable = false;
      limine = {
        panicOnChecksumMismatch = true;
        enrollConfig = false;
        maxGenerations = 10;
      };
    };
  };
}
