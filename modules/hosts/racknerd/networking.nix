{
  fleet.hosts.racknerd.module = {
    systemd.network.networks."10-uplink" = {
      matchConfig.MACAddress = "00:16:3c:ec:fa:6f";
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = false;
        LinkLocalAddressing = "no";
      };
      dhcpV4Config = {
        ClientIdentifier = "mac";
        UseDNS = false;
        UseHostname = false;
      };
      linkConfig.RequiredForOnline = "routable";
    };
  };
}
