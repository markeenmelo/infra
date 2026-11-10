{
  fleet.hosts.thinkpad.module =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      fleet = {
        internalDisplay = "eDP-1";
        lidSwitch = "Lid Switch";
      };
      hardware = {
        firmware = [ pkgs.sof-firmware ];
        cpu.intel.updateMicrocode = true;
        graphics.extraPackages = [ pkgs.intel-media-driver ];
      };
      boot.initrd.availableKernelModules = [
        "xhci_pci"
        "thunderbolt"
        "nvme"
        "usb_storage"
      ];
      services = {
        hardware.bolt.enable = true;
        power-profiles-daemon.enable = true;
        udev = {
          extraHwdb = ''
            battery:BAT0:*:dmi:*
             CHARGE_LIMIT=85,90
          '';
          extraRules = ''
            ACTION=="add", SUBSYSTEM=="pci", ATTR{power/control}="auto"
            ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="8087", ATTR{idProduct}=="0033", ATTR{power/wakeup}="enabled"
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
        services.upower = {
          enableStrictShellChecks = true;
          preStart = "printf 1 > /var/lib/upower/charging-threshold-status";
        };
        services.power-profile-ac = {
          description = "Use power-saver on battery and restore the previous profile on AC";
          wantedBy = [ "power-profiles-daemon.service" ];
          requires = [ "power-profiles-daemon.service" ];
          after = [ "power-profiles-daemon.service" ];
          path = [
            config.services.power-profiles-daemon.package
            config.systemd.package
          ];
          enableStrictShellChecks = true;
          serviceConfig = {
            Type = "oneshot";
            StateDirectory = "power-profile-ac";
            Restart = "on-failure";
            RestartSec = 5;
          };
          script = ''
            saved=$STATE_DIRECTORY/saved
            if systemd-ac-power; then
              if [ -s "$saved" ]; then
                powerprofilesctl set "$(cat "$saved")"
              fi
              rm -f "$saved"
            else
              [ -s "$saved" ] || powerprofilesctl get > "$saved"
              powerprofilesctl set power-saver
            fi
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
        "/var/lib/power-profiles-daemon"
        "/var/lib/power-profile-ac"
      ];
      home-manager.users.marcos = {
        wayland.windowManager.hyprland = {
          settings.monitor = [
            {
              output = config.fleet.internalDisplay;
              position = "0x0";
              mode = "highres";
              scale = 1;
              vrr = 1;
              disabled = lib.generators.mkLuaInline "lid_shut_docked()";
            }
          ];
        };
      };
    };
}
