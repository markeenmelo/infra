{
  flake.modules.nixos.laptop = {
    services.upower.enable = true;
    # No vendor, CPU, firmware, suspend, power-daemon or kernel assumptions.
  };
}
