{
  flake.modules.nixos.base = {
    boot.loader.limine = {
      enable = true;
      panicOnChecksumMismatch = true;
      enrollConfig = false;
      maxGenerations = 10;
    };
  };
}
