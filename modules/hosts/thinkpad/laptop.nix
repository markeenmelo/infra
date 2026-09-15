{
  fleet.hosts.thinkpad.module = {
    services.logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "suspend";
      HandleLidSwitchDocked = "ignore";
    };
    services.hardware.bolt.enable = true;
    environment.persistence."/persist".directories = [ "/var/lib/boltd" ];
  };
}
