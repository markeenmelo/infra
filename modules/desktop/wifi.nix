{
  fleet.hosts.thinkpad.module = _: {
    networking.networkmanager.wifi.powersave = true;
    users.users.marcos.extraGroups = [ "networkmanager" ];
  };
}
