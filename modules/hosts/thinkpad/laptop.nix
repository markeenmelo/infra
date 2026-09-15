{
  fleet.hosts.thinkpad.module = {
    services.thermald.enable = true;
    services.udev.extraHwdb = ''
      battery:BAT0:*:dmi:*
       CHARGE_LIMIT=85,90
    '';
    systemd.services.upower.preStart = "printf 1 > /var/lib/upower/charging-threshold-status";
    services.hardware.bolt.enable = true;
    environment.persistence."/persist".directories = [ "/var/lib/boltd" ];
  };
}
