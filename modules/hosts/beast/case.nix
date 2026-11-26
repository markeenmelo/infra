{
  fleet.hosts.beast.module =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      openrgb = config.services.hardware.openrgb;
      gaming = (pkgs.formats.yaml { }).generate "fan2go-gaming.yaml" {
        dbPath = "/var/lib/fan2go/fan2go.db";
        sensors = [
          {
            id = "cpu";
            hwmon = {
              platform = "coretemp";
              index = 1;
            };
          }
        ];
        curves = [
          {
            id = "gaming";
            linear = {
              sensor = "cpu";
              steps = [
                { "40" = "30%"; }
                { "60" = "60%"; }
                { "72" = "100%"; }
              ];
            };
          }
        ];
        fans =
          map
            (channel: {
              id = "fan${toString channel}";
              hwmon = {
                platform = "nct6798";
                rpmChannel = channel;
                pwmChannel = channel;
              };
              curve = "gaming";
              neverStop = true;
              minPwm = 96;
              startPwm = 120;
              maxPwm = 255;
              pwmMap.identity = { };
              setPwmToGetPwmMap.identity = { };
            })
            [
              1
              2
              3
            ];
      };
      lighting = pkgs.writeShellApplication {
        name = "beast-lighting";
        runtimeInputs = [
          openrgb.package
          pkgs.gnugrep
        ];
        text = ''
          lighting=$1
          server=127.0.0.1:${toString openrgb.server.port}
          for _ in $(seq 30); do
            devices=$(openrgb --client "$server" --list-devices 2> /dev/null) && [ -n "$devices" ] && break
            sleep 2
          done
          echo "$devices" | grep -E '^[0-9]+: ' | while IFS=: read -r index name; do
            name=''${name# }
            case $lighting:$name in
              gaming:"EVGA"*) mode=(--mode "Rainbow Wave") ;;
              gaming:*) mode=(--mode Rainbow) ;;
              off:"ASUS ROG Strix LC") mode=(--mode Direct --color 000000) ;;
              off:*) mode=(--mode Off) ;;
            esac
            openrgb --client "$server" --device "$index" "''${mode[@]}" > /dev/null || echo "beast-lighting: $name refused $lighting" >&2
          done
        '';
      };
    in
    {
      boot.kernelModules = [ "nct6775" ];
      services.hardware.openrgb = {
        enable = true;
        motherboard = "intel";
      };
      fleet.loopbackGuards.openrgb = {
        ports = [ openrgb.server.port ];
        users = [
          "root"
          "marcos"
        ];
      };
      systemd.services = {
        fan2go-gaming = {
          description = "fan2go with beast's gaming fan curve";
          after = [ "systemd-modules-load.service" ];
          serviceConfig = {
            ExecStart = "${lib.getExe pkgs.fan2go} -c ${gaming} --no-style";
            Restart = "always";
            RestartSec = 10;
            StateDirectory = "fan2go";
          };
        };
        beast-mode = {
          description = "Follow the power profile with beast's fans and lighting";
          wantedBy = [ "multi-user.target" ];
          after = [
            "power-profiles-daemon.service"
            "openrgb.service"
          ];
          wants = [ "openrgb.service" ];
          path = [
            config.services.power-profiles-daemon.package
            config.systemd.package
            lighting
          ];
          enableStrictShellChecks = true;
          serviceConfig = {
            Restart = "always";
            RestartSec = 5;
          };
          script = ''
            applied=
            while true; do
              profile=$(powerprofilesctl get) || { sleep 2; continue; }
              if [ "$profile" != "$applied" ]; then
                if [ "$profile" = performance ]; then
                  systemctl start fan2go-gaming.service
                  beast-lighting gaming
                else
                  systemctl stop fan2go-gaming.service
                  beast-lighting off
                fi
                applied=$profile
              fi
              sleep 2
            done
          '';
        };
      };
      preservation.preserveAt."/persist".directories = [
        "/var/lib/OpenRGB"
        "/var/lib/fan2go"
      ];
    };
}
