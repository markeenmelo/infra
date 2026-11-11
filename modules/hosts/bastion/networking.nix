{ config, ... }:
{
  fleet.hosts.bastion.module =
    let
      inherit (config.fleet.hosts.bastion.lan)
        address
        gateway
        mac
        routes
        ;
    in
    {
      services.tailscale = {
        useRoutingFeatures = "server";
        extraSetFlags = [ "--advertise-routes=${routes.homelab},${routes.iot},${routes.kids}" ];
      };
      networking.nftables = {
        enable = true;
        tables.tailnet-routes = {
          family = "inet";
          content = ''
            chain output {
              type filter hook output priority -150; policy accept;
              ip daddr { ${routes.iot}, ${routes.kids} } ct state new reject
            }
            chain forward {
              type filter hook forward priority -200; policy accept;
              ip daddr { ${routes.iot}, ${routes.kids} } ct state new iifname != "tailscale0" drop
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
          address = [ "${address}/24" ];
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
