{
  fleet.hosts.inspiron.module =
    { config, ... }:
    {
      sops = {
        secrets.kids-wifi-psk.restartUnits = [ "NetworkManager-ensure-profiles.service" ];
        templates."kids-wifi.env".content = "KIDS_WIFI_PSK='${config.sops.placeholder.kids-wifi-psk}'";
      };
      networking.networkmanager = {
        enable = true;
        ensureProfiles = {
          environmentFiles = [ config.sops.templates."kids-wifi.env".path ];
          profiles.MN-Kids = {
            connection = {
              id = "MN-Kids";
              type = "wifi";
            };
            wifi = {
              ssid = "MN-Kids";
              cloned-mac-address = "permanent";
            };
            ipv6.method = "disabled";
            wifi-security = {
              key-mgmt = "sae";
              psk = "$KIDS_WIFI_PSK";
            };
          };
        };
      };
      services.tailscale = {
        extraUpFlags = [
          "--reset"
          "--accept-dns=false"
        ];
        extraSetFlags = [ "--accept-dns=false" ];
      };
    };
}
