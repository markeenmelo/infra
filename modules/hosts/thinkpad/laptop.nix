{
  fleet.hosts.thinkpad.module = {
    services.thermald.enable = true;
    services.hardware.bolt.enable = true;
    environment.persistence."/persist".directories = [ "/var/lib/boltd" ];
  };
}
