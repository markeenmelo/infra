{
  # Shared boot policy; the storage owner supplies firmware/device facts.
  flake.modules.nixos.limine = {
    boot.loader = {
      grub.enable = false;
      systemd-boot.enable = false;
      limine = {
        panicOnChecksumMismatch = true;
        enrollConfig = false;
        maxGenerations = 10;
        # Upstream contributes a default wallpaper after its empty option default.
        style.wallpapers = [ ];
      };
    };
  };
}
