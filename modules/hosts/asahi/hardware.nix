{ inputs, ... }:
{
  fleet.hosts.asahi.module =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ inputs.nixos-apple-silicon.nixosModules.apple-silicon-support ];
      hardware.asahi = {
        enable = true;
        peripheralFirmwareDirectory = null;
        avd = {
          vaapi-support = true;
          codecs = [ "all" ];
        };
      };
      nixpkgs.config.allowUnfreePackages = [ "widevine-cdm" ];
      environment.sessionVariables = {
        MOZ_DISABLE_RDD_SANDBOX = "1";
        MOZ_GMP_PATH = "${pkgs.widevine-cdm}/gmp-widevinecdm/system-installed";
      };
      # shortcut: MN-Home's 6 GHz BSS associates but passes no traffic on this BCM4388 firmware, drop when linux-asahi fixes it
      networking.networkmanager.ensureProfiles.profiles.MN-Home.wifi.band = "a";
      boot.kernelParams = [
        "appledrm.show_notch=1"
        "appledrm.hdmi_audio=1"
      ];
      environment.shellAliases.switch-os = "sudo ${lib.getExe' pkgs.asahi-bless "asahi-bless"} --set-boot-macos --next --yes && systemctl reboot";
      services.tuned = {
        enable = true;
        ppdSupport = true;
        profiles = {
          asahi-balanced.main.summary = "Asahi defaults";
          # shortcut: 2.208 GHz P-core cap is a starting point, not measured; tune after a battery baseline
          asahi-power-saver.sysfs = {
            "/sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq" = 2208000;
            "/sys/devices/system/cpu/cpufreq/policy7/scaling_max_freq" = 2208000;
          };
          asahi-balanced-battery.main.include = "asahi-power-saver";
          asahi-performance.cpu.governor = "performance";
        };
        ppdSettings = {
          main = {
            default = "balanced";
            battery_detection = true;
          };
          profiles = {
            power-saver = "asahi-power-saver";
            balanced = "asahi-balanced";
            performance = "asahi-performance";
          };
          battery.balanced = "asahi-balanced-battery";
        };
      };
      systemd.services = {
        tuned.restartTriggers = lib.mapAttrsToList (
          name: _: config.environment.etc."tuned/profiles/${name}/tuned.conf".source
        ) config.services.tuned.profiles;
        tuned-ppd.restartTriggers = [ config.environment.etc."tuned/ppd.conf".source ];
      };
      home-manager.users.marcos = {
        home.packages = [
          pkgs.muvm
          pkgs.fex
        ];
        programs.zen-browser.policies.Preferences =
          lib.mapAttrs
            (_: Value: {
              inherit Value;
              Status = "locked";
            })
            {
              "media.eme.enabled" = true;
              "media.gmp-widevinecdm.enabled" = true;
              "media.gmp-widevinecdm.visible" = true;
              "media.gmp-widevinecdm.autoupdate" = false;
              "media.gmp-widevinecdm.version" = "system-installed";
            };
        services.wluma = {
          enable = true;
          systemd.target = "graphical-session.target";
          settings = {
            als.iio = {
              path = "/sys/bus/iio/devices";
              # shortcut: wluma's README example thresholds, not measured on this sensor; tune if auto-brightness picks the wrong band
              thresholds = {
                "0" = "night";
                "20" = "dark";
                "80" = "dim";
                "250" = "normal";
                "500" = "bright";
                "800" = "outdoors";
              };
            };
            output.backlight = [
              {
                name = "eDP-1";
                path = "/sys/class/backlight/apple-panel-bl";
                capturer = "wayland";
              }
            ];
          };
        };
        programs.umbriel.settings.output =
          let
            scale = 4.0 / 3;
            panelWidth = builtins.floor (3024 / scale);
          in
          {
            eDP-1 = {
              inherit scale;
              position = [
                0
                0
              ];
            };
            HDMI-A-1 = {
              mode = "5120x1440@120";
              position = [
                ((panelWidth - 5120) / 2)
                (-1440)
              ];
              layout.scrolling.default_extent_fraction = 1.0 / 3;
            };
          };
        programs.noctalia.settings = {
          bar.default.thickness = 56;
          idle.behavior.suspend = {
            action = "command";
            # shortcut: linux-asahi wakes from s2idle on the lid and power button only, so on AC with a USB device attached idle never suspends; drop when a USB key press wakes it
            command = "${lib.getExe' config.systemd.package "systemd-ac-power"} && ${lib.getExe' pkgs.coreutils "ls"} /sys/bus/usb/devices/usb* > /dev/null 2>&1 || ${lib.getExe' config.systemd.package "systemctl"} suspend";
          };
        };
      };
    };
}
