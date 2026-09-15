{
  flake.modules.nixos.laptop = {
    services.upower.enable = true;
    services.power-profiles-daemon.enable = true;
    environment.persistence."/persist".directories = [
      "/var/lib/power-profiles-daemon"
      "/var/lib/systemd/backlight"
      "/var/lib/systemd/rfkill"
    ];
  };
}
