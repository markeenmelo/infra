{
  fleet.hosts.racknerd.module = {
    services.resolved.settings.Resolve = {
      DNS = [
        "9.9.9.9#dns.quad9.net"
        "149.112.112.112#dns.quad9.net"
      ];
      DNSOverTLS = "yes";
    };
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
