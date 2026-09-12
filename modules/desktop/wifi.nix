{
  fleet.hosts.thinkpad.module =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.fleet.wifi;
      campus = cfg.senecaSopsFile != null;
      service = "fleet-wifi-environment";
      environmentFile = "/run/${service}/credentials.env";
      restartUnits = [
        "${service}.service"
        "NetworkManager-ensure-profiles.service"
      ];
      secret = sopsFile: {
        inherit sopsFile restartUnits;
        owner = "root";
      };
    in
    {
      options.fleet.wifi.senecaSopsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Reviewed encrypted SOPS YAML containing filled seneca-identity and seneca-password (no replacement markers). Null blocks campus provisioning; never place credentials in Nix.";
      };
      config = {
        networking.networkmanager.wifi.powersave = true;
        users.users.marcos.extraGroups = [ "networkmanager" ];
        # Operator-run private MAC/decryption and filled-scalar audit, 2026-09-10.
        # No campus connection was tested; this refactor changes no review.
        fleet.wifi.senecaSopsFile = ../../secrets/hosts/thinkpad-senecanet.yaml;
        fleet.bootstrap.missing =
          lib.optional (!campus)
            "Replace both encrypted markers in secrets/hosts/thinkpad-senecanet.yaml using SOPS locally, then set fleet.wifi.senecaSopsFile to the reviewed file; SenecaNET is not provisioned while null.";
        sops.secrets = {
          wifi-psk = secret ../../secrets/hosts/thinkpad.yaml;
        }
        // lib.optionalAttrs campus {
          seneca-identity = secret cfg.senecaSopsFile;
          seneca-password = secret cfg.senecaSopsFile;
        };
        networking.networkmanager.ensureProfiles = {
          environmentFiles = [ environmentFile ];
          profiles = {
            MN-Home = {
              connection = {
                id = "MN-Home";
                type = "wifi";
                # Reuse the existing profile identity, not a hardware UUID.
                uuid = "8d9f7dd6-a1fb-5afa-b745-19d00cc548dc";
                autoconnect = true;
              };
              wifi = {
                ssid = "MN-Home";
                mode = "infrastructure";
              };
              wifi-security = {
                key-mgmt = "wpa-psk";
                psk = "$HOME_WIFI_PSK";
                psk-flags = 0;
              };
              ipv4.method = "auto";
              ipv6.method = "auto";
            };
          }
          // lib.optionalAttrs campus {
            SenecaNET = {
              connection = {
                id = "SenecaNET";
                type = "wifi";
                autoconnect = false;
              };
              wifi = {
                ssid = "SenecaNET";
                mode = "infrastructure";
              };
              wifi-security.key-mgmt = "wpa-eap";
              "802-1x" = {
                eap = "peap";
                phase2-auth = "mschapv2";
                ca-cert = "/etc/ssl/certs/ca-certificates.crt";
                domain-suffix-match = "senecapolytechnic.ca";
                anonymous-identity = "";
                identity = "$SENECA_IDENTITY";
                password = "$SENECA_PASSWORD";
                password-flags = 0;
              };
              ipv4.method = "auto";
              ipv6.method = "auto";
            };
          };
        };
        # Activation-based SOPS decryption is already required by fleet.secrets.
        # This root-only, runtime-only adapter escapes raw secrets; NixOS still
        # generates the profiles, substitutes the environment and reloads NM.
        systemd.services = {
          ${service} = {
            description = "Prepare private SOPS environment for native Wi-Fi profiles";
            before = [ "NetworkManager-ensure-profiles.service" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              RuntimeDirectory = service;
              RuntimeDirectoryMode = "0700";
              UMask = "0077";
              NoNewPrivileges = true;
              ProtectSystem = "strict";
              ProtectHome = true;
              PrivateTmp = true;
              RestrictAddressFamilies = [ "AF_UNIX" ];
            };
            script = ''
              ${lib.getExe pkgs.python3} ${./assets/wifi-environment.py} ${
                lib.escapeShellArgs (
                  [
                    environmentFile
                    "HOME_WIFI_PSK=${config.sops.secrets.wifi-psk.path}"
                  ]
                  ++ lib.optionals campus [
                    "SENECA_IDENTITY=${config.sops.secrets.seneca-identity.path}"
                    "SENECA_PASSWORD=${config.sops.secrets.seneca-password.path}"
                  ]
                )
              }
            '';
          };
          NetworkManager-ensure-profiles = {
            requires = [ "${service}.service" ];
            after = [ "${service}.service" ];
          };
        };
        # psk/password-flags=0: root-owned /run profiles, no competing file secret
        # agent or Noctalia patch. Unknown networks can still prompt normally.
      };
    };
}
