{
  flake.modules.nixos.laptop = {
    services.upower.enable = true;
    services.power-profiles-daemon.enable = true;
    # One power manager: no TLP/auto-cpufreq, forced performance, blanket USB
    # autosuspend, speculative hibernation or battery charge thresholds.
    environment.persistence."/persist".directories = [
      "/var/lib/power-profiles-daemon"
      "/var/lib/systemd/backlight"
      "/var/lib/systemd/rfkill"
    ];
  };
}
