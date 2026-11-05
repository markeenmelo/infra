{
  fleet.hosts.bastion.module =
    let
      mac = "6c:1f:f7:56:0a:10";
      gateway = "192.168.2.1";
      lans = {
        homelab = "192.168.2.0/24";
        iot = "192.168.4.0/24";
        kids = "192.168.20.0/24";
      };
    in
    {
      services.tailscale = {
        useRoutingFeatures = "server";
        extraSetFlags = [ "--advertise-routes=${lans.homelab},${lans.iot},${lans.kids}" ];
      };
      networking.nftables = {
        enable = true;
        tables.tailnet-routes = {
          family = "inet";
          content = ''
            chain output {
              type filter hook output priority -150; policy accept;
              ip daddr { ${lans.iot}, ${lans.kids} } ct state new reject
            }
            chain forward {
              type filter hook forward priority -200; policy accept;
              ip daddr { ${lans.iot}, ${lans.kids} } ct state new iifname != "tailscale0" drop
            }
          '';
        };
      };
      systemd.network = {
        links."10-uplink" = {
          matchConfig.MACAddress = mac;
          linkConfig = {
            Name = "enp4s0";
            WakeOnLan = "magic";
          };
        };
        networks."10-uplink" = {
          matchConfig.MACAddress = mac;
          address = [ "192.168.2.2/24" ];
          gateway = [ gateway ];
          dns = [ gateway ];
          networkConfig = {
            IPv6AcceptRA = false;
            LinkLocalAddressing = "no";
          };
          linkConfig.RequiredForOnline = "routable";
        };
      };
    };
}
