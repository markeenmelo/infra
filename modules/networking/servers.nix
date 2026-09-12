{ lib, ... }:
let
  # Observed networkd DHCP policy, not static addressing guessed from SSH endpoints.
  uplinks = {
    racknerd = {
      mac = "00:16:3c:ec:fa:6f";
      linkLocal = "ipv6";
    };
    bastion = {
      mac = "6c:1f:f7:56:0a:10";
      linkLocal = "no";
    };
  };
in
{
  fleet.hosts = lib.mapAttrs (name: uplink: {
    module = {
      # Bastion's direct LAN root/marcos access works while Tailscale needs
      # login; MAC/DHCP routing and independent recovery reviewed 2026-09-11.
      fleet.installation.networkReviewed = lib.mkIf (name == "bastion") true;
      networking.useNetworkd = true;
      services.resolved.enable = true;
      systemd.network.networks."10-${name}-uplink" = {
        matchConfig.MACAddress = uplink.mac;
        networkConfig = {
          DHCP = "ipv4";
          IPv6AcceptRA = false;
          LinkLocalAddressing = uplink.linkLocal;
        };
        dhcpV4Config = {
          ClientIdentifier = "mac";
          UseDNS = true;
          UseRoutes = true;
          UseHostname = false;
          UseDomains = false;
        };
        linkConfig.RequiredForOnline = "routable";
      };
    };
  }) uplinks;
}
