{
  fleet.hosts.bastion.module = {
    networking.useNetworkd = true;
    services.resolved.enable = true;
    systemd.network.networks."10-bastion-uplink" = {
      matchConfig.MACAddress = "6c:1f:f7:56:0a:10";
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = false;
        LinkLocalAddressing = "no";
      };
      dhcpV4Config = {
        ClientIdentifier = "mac";
        UseHostname = false;
      };
      linkConfig.RequiredForOnline = "routable";
    };
  };
}
