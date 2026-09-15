{
  flake.modules.nixos.desktop =
    { config, lib, ... }:
    {
      networking.networkmanager.enable = true;
      users.users = lib.optionalAttrs (config.fleet.access.admin != null) {
        ${config.fleet.access.admin}.extraGroups = [ "networkmanager" ];
      };
      environment.persistence."/persist".directories = [
        {
          directory = "/etc/NetworkManager/system-connections";
          mode = "0700";
        }
        "/var/lib/NetworkManager"
      ];
    };

  flake.modules.homeManager.desktop = { pkgs, ... }: {
    home.packages = [ pkgs.networkmanagerapplet ];
    xdg.configFile."autostart/nm-applet.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=nm-applet
      Hidden=true
    '';
  };

  fleet.hosts.thinkpad.module =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      service = "fleet-wifi-environment";
      environmentFile = "/run/${service}/credentials.env";
      restartUnits = [
        "${service}.service"
        "NetworkManager-ensure-profiles.service"
      ];
      secret = sopsFile: {
        inherit sopsFile restartUnits;
        owner = "root";
        mode = "0400";
      };
      prepareEnvironment = pkgs.writeScript service ''
        #!${lib.getExe pkgs.python3}
        import json
        from pathlib import Path
        import sys
        import tempfile

        sources = {
            "HOME_WIFI_PSK": "${config.sops.secrets.wifi-psk.path}",
            "SENECA_IDENTITY": "${config.sops.secrets.seneca-identity.path}",
            "SENECA_PASSWORD": "${config.sops.secrets.seneca-password.path}",
        }
        markers = ("__SET_SENECA_IDENTITY_LOCALLY__", "__SET_SENECA_PASSWORD_LOCALLY__")

        def encode(name, value):
            if name not in sources or not value or value in markers:
                raise ValueError("Invalid credential")
            if any((ord(c) < 32 and c != "\t") or ord(c) == 127 for c in value):
                raise ValueError("Expected a single-line credential")
            if name == "SENECA_IDENTITY" and ("@" in value or any(c.isspace() for c in value)):
                raise ValueError("Expected the campus username before @")
            for raw, escaped in (("\\", "\\\\"), ("\t", "\\t"), (" ", "\\s")):
                value = value.replace(raw, escaped)
            return json.dumps(value, ensure_ascii=False)

        def prepare(output, entries):
            lines = [
                f"{name}={encode(name, Path(filename).read_text(encoding='utf-8'))}\n"
                for name, filename in entries.items()
            ]
            with tempfile.NamedTemporaryFile(
                mode="w", encoding="utf-8", dir=output.parent, delete=False
            ) as stream:
                stream.writelines(lines)
                temporary = Path(stream.name)
            temporary.replace(output)

        def self_test():
            value = " a\\b\t\"'$X;é "
            assert json.loads(encode("SENECA_PASSWORD", value)) == (
                r"\sa\\b\t" + "\"'$X;é" + r"\s"
            )
            assert encode("SENECA_IDENTITY", "student") == '"student"'
            invalid = [("SENECA_PASSWORD", v) for v in (
                "", "\0", "x\n", "x\r", "\x01", "\x7f", *markers
            )] + [("SENECA_IDENTITY", v) for v in ("a@b", "a b", "a\tb")]
            invalid.append(("UNKNOWN", "value"))
            for name, value in invalid:
                try:
                    encode(name, value)
                except ValueError:
                    continue
                raise AssertionError("Invalid credential accepted")

        if __name__ == "__main__":
            try:
                if sys.argv[1:] == ["--self-test"]:
                    self_test()
                    print("Wi-Fi credential self-check passed.")
                elif sys.argv[1:]:
                    raise ValueError("Unexpected arguments")
                else:
                    prepare(Path("${environmentFile}"), sources)
            except Exception:
                sys.exit("Wi-Fi credential preparation failed; review the private SOPS inputs.")
      '';
    in
    {
      sops.secrets = {
        wifi-psk = secret ../../secrets/hosts/thinkpad.yaml;
        seneca-identity = secret ../../secrets/hosts/thinkpad-senecanet.yaml;
        seneca-password = secret ../../secrets/hosts/thinkpad-senecanet.yaml;
      };
      networking.networkmanager = {
        wifi.powersave = true;
        ensureProfiles = {
          environmentFiles = [ environmentFile ];
          profiles = {
            MN-Home = {
              connection = {
                id = "MN-Home";
                type = "wifi";
                uuid = "dc80e393-1a04-4c99-b1c9-9b32a74c9367";
                autoconnect = true;
              };
              wifi = {
                ssid = "MN-Home";
                mode = "infrastructure";
              };
              wifi-security = {
                key-mgmt = "sae";
                psk = "$HOME_WIFI_PSK";
                psk-flags = 0;
              };
              ipv4.method = "auto";
              ipv6.method = "auto";
            };
            SenecaNET = {
              connection = {
                id = "SenecaNET";
                type = "wifi";
                autoconnect = true;
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
      };
      systemd.services = {
        ${service} = {
          description = "Prepare private SOPS environment for native Wi-Fi profiles";
          before = [ "NetworkManager-ensure-profiles.service" ];
          serviceConfig = {
            ExecStart = prepareEnvironment;
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
        };
        NetworkManager-ensure-profiles = {
          requires = [ "${service}.service" ];
          after = [ "${service}.service" ];
        };
      };
    };
}
