{
  flake.modules.nixos.desktop =
    { config, ... }:
    let
      seneca = ../secrets/hosts/${config.networking.hostName}-senecanet.yaml;
    in
    {
      sops = {
        secrets = {
          wifi-psk.restartUnits = [ "NetworkManager-ensure-profiles.service" ];
          seneca-identity = {
            sopsFile = seneca;
            restartUnits = [ "NetworkManager-ensure-profiles.service" ];
          };
          seneca-password = {
            sopsFile = seneca;
            restartUnits = [ "NetworkManager-ensure-profiles.service" ];
          };
        };
        templates."wifi.env".content = ''
          SENECA_IDENTITY=${config.sops.placeholder.seneca-identity}
          SENECA_PASSWORD='${config.sops.placeholder.seneca-password}'
          WIFI_PSK='${config.sops.placeholder.wifi-psk}'
        '';
      };
      networking.networkmanager = {
        wifi.macAddress = "stable-ssid";
        ensureProfiles = {
          environmentFiles = [ config.sops.templates."wifi.env".path ];
          profiles = {
            MN-Home = {
              connection = {
                id = "MN-Home";
                type = "wifi";
              };
              wifi = {
                ssid = "MN-Home";
                cloned-mac-address = "permanent";
              };
              ipv6.method = "disabled";
              wifi-security = {
                key-mgmt = "sae";
                psk = "$WIFI_PSK";
              };
            };
            SenecaNET = {
              connection = {
                id = "SenecaNET";
                type = "wifi";
              };
              wifi.ssid = "SenecaNET";
              ipv6.method = "disabled";
              wifi-security.key-mgmt = "wpa-eap";
              "802-1x" = {
                eap = "peap";
                phase2-auth = "mschapv2";
                ca-cert = "/etc/ssl/certs/ca-certificates.crt";
                domain-suffix-match = "senecapolytechnic.ca";
                anonymous-identity = "anonymous@senecapolytechnic.ca";
                identity = "$SENECA_IDENTITY";
                password = "$SENECA_PASSWORD";
              };
            };
          };
        };
      };
    };
}
