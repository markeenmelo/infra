{
  fleet.hosts.thinkpad.module =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      hardware = {
        firmware = [ pkgs.sof-firmware ];
        cpu.intel.updateMicrocode = true;
        graphics.extraPackages = [ pkgs.intel-media-driver ];
      };
      boot = {
        initrd.availableKernelModules = [
          "xhci_pci"
          "thunderbolt"
          "nvme"
          "usb_storage"
        ];
        extraModprobeConfig = "options snd_hda_intel power_save=1";
        kernel.sysctl = {
          "kernel.nmi_watchdog" = 0;
          "vm.dirty_writeback_centisecs" = 1500;
        };
      };
      services = {
        hardware.bolt.enable = true;
        udev = {
          extraHwdb = ''
            battery:BAT0:*:dmi:*
             CHARGE_LIMIT=85,90
          '';
          extraRules = ''
            ACTION=="add", SUBSYSTEM=="pci", ATTR{power/control}="auto"
            ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="8087", ATTR{idProduct}=="0033", ATTR{power/wakeup}="enabled"
            ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="1532", ATTR{idProduct}=="0083", ATTR{power/control}="auto"
            ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="AC", RUN+="${lib.getExe' config.systemd.package "systemctl"} restart --no-block power-profile-ac.service"
          '';
        };
      };
      systemd = {
        sleep.settings.Sleep = {
          AllowHibernation = false;
          AllowHybridSleep = false;
          AllowSuspendThenHibernate = false;
        };
        services.power-profile-ac = {
          description = "Hold power-saver and dim the panel on battery, and release the hold and restore the brightness on AC";
          wantedBy = [ "power-profiles-daemon.service" ];
          requires = [ "power-profiles-daemon.service" ];
          after = [ "power-profiles-daemon.service" ];
          path = [
            config.services.power-profiles-daemon.package
            config.systemd.package
            pkgs.coreutils
          ];
          enableStrictShellChecks = true;
          serviceConfig = {
            Type = "oneshot";
            StateDirectory = "power-profile-ac";
            Restart = "on-failure";
            RestartSec = 5;
          };
          # shortcut: the 40% brightness cap on battery is a starting point, not measured; tune after a battery baseline
          script = ''
            ac=$(cat /sys/class/power_supply/AC/online)
            held=$(systemctl is-active power-saver-on-battery || true)
            if [ "$ac" = 1 ]; then
              [ "$held" != active ] || systemctl stop power-saver-on-battery
            elif [ "$held" != active ]; then
              systemd-run --collect --unit=power-saver-on-battery \
                --property=BindsTo=power-profiles-daemon.service --property=After=power-profiles-daemon.service \
                powerprofilesctl launch --profile power-saver --reason battery sleep infinity
            fi
            for panel in /sys/class/backlight/*; do
              [ -e "$panel/brightness" ] || continue
              bright=$STATE_DIRECTORY/brightness-''${panel##*/}
              if [ "$ac" = 1 ]; then
                if [ -s "$bright" ]; then
                  cat "$bright" > "$panel/brightness"
                fi
                rm -f "$bright"
              elif [ ! -s "$bright" ]; then
                cat "$panel/brightness" > "$bright"
                cap=$(($(cat "$panel/max_brightness") * 40 / 100))
                if [ "$(cat "$panel/brightness")" -gt "$cap" ]; then
                  echo "$cap" > "$panel/brightness"
                fi
              fi
            done
          '';
        };
      };
      powerManagement = {
        powerDownCommands = ''
          if ! ${lib.getExe' config.systemd.package "systemd-ac-power"}; then
            for device in /sys/bus/pci/drivers/xhci_hcd/0000:*; do echo disabled > "$device/power/wakeup"; done
          fi
        '';
        resumeCommands = ''
          for device in /sys/bus/pci/drivers/xhci_hcd/0000:*; do echo enabled > "$device/power/wakeup"; done
        '';
      };
      preservation.preserveAt."/persist".directories = [
        "/var/lib/boltd"
        "/var/lib/power-profile-ac"
      ];
      home-manager.users.marcos.programs.umbriel.settings.output =
        let
          panelWidth = 1920;
          above = width: [
            ((panelWidth - width) / 2)
            (-1440)
          ];
        in
        {
          eDP-1.position = [
            0
            0
          ];
          "Dell Inc. DELL U3423WE 4TSGMP3" = {
            mode = "3440x1440@59.97";
            position = above 3440;
          };
          "Samsung Electric Company Odyssey G93SC HCSY300098" = {
            position = above 5120;
            hdr = "on";
          };
        };
    };
}
