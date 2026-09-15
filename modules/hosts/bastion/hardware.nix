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
      inherit (config.boot.kernelPackages) kernel kernelModuleMakeFlags;
      inherit (pkgs.ugreen-leds-cli) src version;
      diskLeds = {
        disk1 = "ata-ST4000VN006-3CW104_ZW63V4FM";
        disk2 = "ata-TOSHIBA_HDWG440_2270A00MFZ1G";
      };
      ledDriver = pkgs.stdenv.mkDerivation {
        pname = "led-ugreen";
        version = "${version}-${kernel.version}";
        inherit src;
        sourceRoot = "${src.name}/kmod";
        nativeBuildInputs = kernel.moduleBuildDependencies;
        hardeningDisable = [ "pic" ];
        makeFlags = kernelModuleMakeFlags ++ [
          "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
        ];
        installPhase = ''
          runHook preInstall
          install -Dm644 led-ugreen.ko $out/lib/modules/${kernel.modDirVersion}/extra/led-ugreen.ko
          runHook postInstall
        '';
      };
      diskMonitor = pkgs.runCommandCC "ugreen-blink-disk-${version}" { } ''
        mkdir -p $out/bin
        $CXX -std=c++17 -O2 ${src}/scripts/blink-disk.cpp -o $out/bin/ugreen-blink-disk
      '';
    in
    {
      system.stateVersion = "26.05";
      boot.initrd.availableKernelModules = [
        "xhci_pci"
        "nvme"
        "ahci"
        "sd_mod"
      ];
      boot.extraModulePackages = [
        ledDriver
        (config.boot.kernelPackages.it87.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [
            (pkgs.fetchpatch {
              name = "it87-tachometer-mask.patch";
              url = "https://github.com/frankcrawford/it87/commit/7dee1a363e3c70430c2cf8eb3a556bdc2a45afc2.patch";
              hash = "sha256-kZt25rEo7p73qRBv0aedhO0Om27Qw8gUc+KVBR2jngE=";
            })
          ];
        }))
      ];
      boot.kernelModules = [
        "i2c-i801"
        "i2c-dev"
        "led-ugreen"
        "ledtrig-netdev"
        "ledtrig-oneshot"
      ];
      systemd.services = {
        ugreen-leds = {
          description = "Initialize UGREEN front-panel LEDs";
          wantedBy = [ "multi-user.target" ];
          wants = map (led: "ugreen-${led}.service") (lib.attrNames diskLeds);
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
            ${pkgs.bash}/bin/bash ${src}/scripts/ugreen-probe-leds
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
            echo enp3s0 > /sys/class/leds/netdev/device_name
            echo 100 > /sys/class/leds/netdev/interval
            echo 1 > /sys/class/leds/netdev/link
            echo 1 > /sys/class/leds/netdev/tx
            echo 1 > /sys/class/leds/netdev/rx
          '';
        };
      }
      // lib.mapAttrs' (
        led: id:
        let
          device = "/dev/disk/by-id/${id}";
          deviceUnit = "${utils.escapeSystemdPath device}.device";
          ledPath = "/sys/class/leds/${led}";
        in
        lib.nameValuePair "ugreen-${led}" {
          description = "UGREEN ${led} presence and activity";
          wantedBy = [ deviceUnit ];
          bindsTo = [ deviceUnit ];
          requires = [ "ugreen-leds.service" ];
          after = [
            deviceUnit
            "ugreen-leds.service"
          ];
          partOf = [ "ugreen-leds.service" ];
          preStart = ''
            echo oneshot > ${ledPath}/trigger
            echo 100 > ${ledPath}/delay_on
            echo 100 > ${ledPath}/delay_off
            echo 1 > ${ledPath}/invert
            echo 128 > ${ledPath}/brightness
          '';
          script = ''
            device=$(readlink -e ${lib.escapeShellArg device})
            exec ${diskMonitor}/bin/ugreen-blink-disk 0.1 "''${device##*/}" ${led}
          '';
          postStop = ''
            echo 0 > ${ledPath}/brightness
          '';
          serviceConfig = {
            Restart = "on-failure";
            RestartSec = "2s";
            NoNewPrivileges = true;
            PrivateNetwork = true;
            ProtectHome = true;
            ProtectSystem = "strict";
            ReadWritePaths = [ ledPath ];
            DevicePolicy = "closed";
          };
        }
      ) diskLeds;
      hardware.enableRedistributableFirmware = true;
      hardware.cpu.intel.updateMicrocode = true;
      boot.loader.limine.extraConfig = "graphics: no";
    };
}
