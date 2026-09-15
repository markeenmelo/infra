{
  fleet.hosts.racknerd.module = {
    networking.useNetworkd = true;
    services.resolved.enable = true;
    systemd.network.networks."10-racknerd-uplink" = {
      matchConfig.MACAddress = "00:16:3c:ec:fa:6f";
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = false;
        LinkLocalAddressing = "ipv6";
      };
      dhcpV4Config = {
        ClientIdentifier = "mac";
        UseHostname = false;
      };
      linkConfig.RequiredForOnline = "routable";
    };
  };
}
