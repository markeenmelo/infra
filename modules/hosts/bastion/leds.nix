{
  fleet.hosts.bastion.module =
    {
      config,
      lib,
      pkgs,
      utils,
      ...
    }:
    let
      inherit (pkgs.ugreen-leds-cli) src version;
      driver = config.boot.kernelPackages.callPackage (
        {
          stdenv,
          kernel,
          kernelModuleMakeFlags,
        }:
        stdenv.mkDerivation {
          pname = "led-ugreen";
          version = "${version}-${kernel.version}";
          inherit src;
          sourceRoot = "${src.name}/kmod";
          nativeBuildInputs = kernel.moduleBuildDependencies;
          hardeningDisable = [ "pic" ];
          makeFlags = kernelModuleMakeFlags ++ [
            "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
            "INSTALL_MOD_PATH=$(out)"
          ];
        }
      ) { };
      uplink = config.systemd.network.links."10-uplink".linkConfig.Name;
      disks = import ./_disks.nix;
    in
    {
      boot.extraModulePackages = [ driver ];
      boot.kernelModules = [
        "i2c-i801"
        "ledtrig-netdev"
      ];
      systemd.services = lib.mkMerge [
        {
          ugreen-leds = {
            description = "Initialize UGREEN front-panel LEDs";
            enableStrictShellChecks = true;
            wantedBy = [ "multi-user.target" ];
            requires = [ "systemd-modules-load.service" ];
            after = [ "systemd-modules-load.service" ];
            path = [
              pkgs.kmod
              pkgs.i2c-tools
            ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              TimeoutStartSec = "15s";
            };
            script = ''
              ${lib.getExe pkgs.bash} ${src}/scripts/ugreen-probe-leds
              for led in power netdev disk1 disk2 disk3 disk4; do
                echo none > /sys/class/leds/$led/trigger
                echo 0 > /sys/class/leds/$led/brightness
                echo '0 255 0' > /sys/class/leds/$led/color
              done
              echo '0 0 255' > /sys/class/leds/power/color
              echo 128 > /sys/class/leds/power/brightness
              echo '255 165 0' > /sys/class/leds/netdev/color
              echo 128 > /sys/class/leds/netdev/brightness
              echo netdev > /sys/class/leds/netdev/trigger
              echo ${uplink} > /sys/class/leds/netdev/device_name
              echo 1 > /sys/class/leds/netdev/link
              echo 0 > /sys/class/leds/netdev/tx
              echo 0 > /sys/class/leds/netdev/rx
            '';
          };
        }
        (lib.mapAttrs' (
          led: id:
          let
            device = "${utils.escapeSystemdPath "/dev/disk/by-id/${id}"}.device";
            path = "/sys/class/leds/${led}";
          in
          lib.nameValuePair "ugreen-${led}" {
            description = "UGREEN ${led} presence";
            enableStrictShellChecks = true;
            wantedBy = [ device ];
            bindsTo = [ device ];
            requires = [ "ugreen-leds.service" ];
            after = [
              device
              "ugreen-leds.service"
            ];
            partOf = [ "ugreen-leds.service" ];
            script = "echo 128 > ${path}/brightness";
            postStop = "echo 0 > ${path}/brightness";
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              NoNewPrivileges = true;
              PrivateNetwork = true;
              ProtectHome = true;
              ProtectSystem = "strict";
              ReadWritePaths = [ path ];
              DevicePolicy = "closed";
            };
          }
        ) disks)
      ];
    };
}
