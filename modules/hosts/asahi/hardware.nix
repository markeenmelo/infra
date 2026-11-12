{ inputs, ... }:
{
  fleet.hosts.asahi.module =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      acOnline = "/sys/class/power_supply/macsmc-ac/online";
      internal = config.fleet.internalDisplay;
      acReload = pkgs.writeShellApplication {
        name = "hypr-ac-reload";
        runtimeInputs = [
          config.programs.hyprland.package
          config.systemd.package
        ];
        text = ''
          last=$(cat ${acOnline})
          udevadm monitor --udev --subsystem-match=power_supply | while read -r _; do
            now=$(cat ${acOnline})
            if [ "$now" != "$last" ]; then
              last=$now
              hyprctl reload
            fi
          done
        '';
      };
    in
    {
      imports = [ inputs.nixos-apple-silicon.nixosModules.apple-silicon-support ];
      fleet = {
        internalDisplay = "eDP-1";
        lidSwitch = "Apple SMC power/lid events";
      };
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
          pkgs.spotify-player
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
        systemd.user.services.hypr-ac-reload = {
          Unit = {
            Description = "Reload Hyprland when AC power changes";
            PartOf = [ "graphical-session.target" ];
            After = [ "graphical-session.target" ];
          };
          Service = {
            ExecStart = lib.getExe acReload;
            Restart = "on-failure";
          };
          Install.WantedBy = [ "graphical-session.target" ];
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
                name = internal;
                path = "/sys/class/backlight/apple-panel-bl";
                capturer = "wayland";
              }
            ];
          };
        };
        wayland.windowManager.hyprland = {
          extraLuaFiles.power = ''
            function on_ac()
              local f = io.open("${acOnline}")
              if not f then return true end
              local online = f:read("l") == "1"
              f:close()
              return online
            end
          '';
          settings.monitor = lib.mkAfter (
            [
              {
                output = internal;
                position = "0x0";
                mode = lib.generators.mkLuaInline ''on_ac() and "3024x1964@120" or "3024x1964@60"'';
                scale = 4.0 / 3;
                vrr = 2;
                disabled = lib.generators.mkLuaInline "lid_shut_docked()";
              }
            ]
            ++
              map
                (output: {
                  inherit output;
                  position = "auto-center-up";
                  mode = "5120x1440@120";
                  scale = 1;
                  bitdepth = 8;
                  cm = "srgb";
                  vrr = 0;
                })
                [
                  "HDMI-A-1"
                  "desc:Samsung Electric Company Odyssey G93SC HCSY300098"
                ]
          );
        };
        programs.noctalia.settings.bar.default.thickness = 56;
      };
    };
}
