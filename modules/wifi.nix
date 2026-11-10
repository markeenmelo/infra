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
        '';
      };
      networking.networkmanager = {
        wifi.macAddress = "stable-ssid";
        ensureProfiles = {
          environmentFiles = [ config.sops.templates."wifi.env".path ];
          secrets.entries = [
            {
              matchId = "MN-Home";
              matchSetting = "802-11-wireless-security";
              key = "psk";
              file = config.sops.secrets.wifi-psk.path;
              trim = false;
            }
            {
              matchId = "SenecaNET";
              matchSetting = "802-1x";
              key = "password";
              file = config.sops.secrets.seneca-password.path;
              trim = false;
            }
          ];
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
                psk-flags = 1;
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
                password-flags = 1;
              };
            };
          };
        };
      };
    };
}
