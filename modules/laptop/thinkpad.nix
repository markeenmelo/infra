{
  # Observed Intel ThinkPad and reviewed Thunderbolt authorization policy.
  # No new device, blanket authorization or power-manager choice is introduced.
  fleet.hosts.thinkpad.module = {
    services.thermald.enable = true;
    services.hardware.bolt.enable = true;
    environment.persistence."/persist".directories = [ "/var/lib/boltd" ];
  };
}
