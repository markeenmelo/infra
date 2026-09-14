{
  flake.modules.nixos.base = {
    boot.loader = {
      grub.enable = false;
      systemd-boot.enable = false;
      limine = {
        enable = true;
        panicOnChecksumMismatch = true;
        enrollConfig = false;
        maxGenerations = 10;
      };
    };
  };
}
