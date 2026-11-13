{
  flake.modules.nixos.gaming =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      nvidia = "0x10de";
      rtx3070 = "10de:2488";
      keychron = "3434";
      monitor = "Odyssey G93SC";
      displayPort = "0x0f";
      seat = "seat1";
      flag = "/run/gaming";
      card = "/dev/dri/egpu";
      systemctl = lib.getExe' config.systemd.package "systemctl";
      handover = pkgs.writeShellApplication {
        name = "gaming-handover";
        runtimeInputs = [
          config.systemd.package
          pkgs.coreutils
          pkgs.kmod
          pkgs.ddcutil
          pkgs.gawk
        ];
        text = ''
          inputs=
          case $1 in
            on)
              : > ${flag}
              rmmod nvidia_drm 2>/dev/null || true
              echo 1 > /sys/bus/pci/rescan
              for _ in $(seq 30); do
                if [ -e ${card} ]; then break; fi
                sleep 0.5
              done
              [ -e ${card} ]
              for connector in /sys/class/drm/card*-*; do
                if [ -e "$connector/ddc" ] && grep -qa ${lib.escapeShellArg monitor} "$connector/edid" 2>/dev/null; then
                  bus=$(basename "$(readlink "$connector/ddc")")
                  bus=''${bus#i2c-}
                  previous=$(ddcutil --bus "$bus" --terse getvcp 60 | awk '$3 == "SNC" { print "0" $NF }' || true)
                  inputs+="$bus $previous"$'\n'
                fi
              done
              printf %s "$inputs" > ${flag}
              while read -r bus _; do
                if [ -n "$bus" ]; then
                  ddcutil --bus "$bus" --noverify setvcp 60 ${displayPort} || true
                fi
              done <<< "$inputs"
              ;;
            off)
              if [ -e ${flag} ]; then inputs=$(cat ${flag}); fi
              rm -f ${flag}
              ;;
          esac
          for device in /sys/bus/usb/devices/*; do
            if [ -f "$device/idVendor" ] && [ "$(cat "$device/idVendor")" = ${keychron} ]; then
              echo 0 > "$device/authorized"
              echo 1 > "$device/authorized"
            fi
          done
          if [ "$1" = off ] && [ -n "$inputs" ]; then
            while read -r bus previous; do
              if [ -z "$previous" ]; then continue; fi
              for _ in 1 2 3 4 5; do
                if ddcutil --bus "$bus" --noverify setvcp 60 "$previous"; then break; fi
                sleep 1
              done
            done <<< "$inputs"
          fi
          if [ "$1" = off ]; then
            loginctl terminate-seat ${seat} || true
            sleep 1
            for device in /sys/bus/pci/devices/*; do
              if [ -e "$device/remove" ] && [ "$(cat "$device/vendor")" = ${nvidia} ]; then
                echo 1 > "$device/remove"
              fi
            done
            rmmod nvidia_drm nvidia_modeset nvidia_uvm nvidia 2>/dev/null || true
          fi
        '';
      };
      gaming = pkgs.writeShellApplication {
        name = "gaming";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.libnotify
          pkgs.procps
        ];
        text = ''
          if ${systemctl} is-active --quiet gaming.service; then
            if pgrep -x steam > /dev/null; then steam -shutdown || true; fi
            for _ in $(seq 60); do
              if ! pgrep -x steam > /dev/null; then break; fi
              sleep 0.5
            done
            ${systemctl} stop --no-block gaming.service
          elif ! ${systemctl} start gaming.service; then
            notify-send --app-name=gaming "Gaming" "eGPU not connected"
          fi
        '';
      };
    in
    {
      nixpkgs.config.allowUnfreePackages = [
        "nvidia-kernel-modules"
        "nvidia-x11"
        "steam"
        "steam-unwrapped"
      ];
      boot.kernelModules = [ "ntsync" ];
      services.xserver.videoDrivers = [ "nvidia" ];
      hardware.nvidia = {
        # shortcut: proprietary module, nixpkgs loads the open one's nvidia_uvm at every boot and that fails without the card, switch once it loads lazily
        open = false;
        modesetting.enable = true;
        nvidiaSettings = false;
      };
      programs = {
        gamescope = {
          enable = true;
          enableWsi = true;
        };
        steam = {
          enable = true;
          extraCompatPackages = [ pkgs.proton-ge-bin ];
          extraPackages = [
            pkgs.mangohud
            (pkgs.writeShellScriptBin "steamos-session-select" "exec ${lib.getExe gaming}")
          ];
        };
      };
      services.udev.packages = [
        (pkgs.writeTextDir "etc/udev/rules.d/72-gaming.rules" ''
          ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="${nvidia}", TEST!="${flag}", ATTR{remove}="1"
          SUBSYSTEM=="pci", ATTR{vendor}=="${nvidia}", ENV{ID_SEAT}="${seat}"
          ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="${nvidia}", ATTR{class}=="0x03*", TEST=="${flag}", RUN{builtin}+="kmod load nvidia_drm"
          SUBSYSTEM=="drm", ENV{DEVTYPE}=="drm_minor", KERNEL=="card[0-9]*", ATTRS{vendor}=="${nvidia}", SYMLINK+="${lib.removePrefix "/dev/" card}"
          SUBSYSTEM=="input", ATTRS{idVendor}=="${keychron}", TEST=="${flag}", ENV{ID_SEAT}="${seat}"
        '')
      ];
      systemd.services = {
        gaming = {
          description = "Steam Big Picture on the eGPU";
          after = [ "systemd-user-sessions.service" ];
          wants = [
            "gaming-awake.service"
            "gaming-performance.service"
            "gaming-scheduler.service"
          ];
          environment = {
            XDG_SEAT = seat;
            XDG_SESSION_TYPE = "wayland";
            XDG_SESSION_CLASS = "user";
            WLR_LIBINPUT_NO_DEVICES = "1";
          };
          serviceConfig = {
            User = "marcos";
            PAMName = "login";
            Nice = -10;
            ExecStartPre = "+${lib.getExe handover} on";
            ExecStart = "${lib.getExe config.programs.gamescope.package} --steam --prefer-vk-device ${rtx3070} -W 5120 -H 1440 -w 5120 -h 1440 -r 120 --hdr-enabled -- ${lib.getExe config.programs.steam.package} -gamepadui -steamos3 -pipewire-dmabuf";
            ExecStopPost = "+${lib.getExe handover} off";
            # shortcut: gamescope 3.17 hangs 25 s releasing the card through logind and then crashes, so stop kills it outright; drop when it exits cleanly
            KillSignal = "SIGKILL";
          };
        };
        gaming-scheduler = {
          description = "Run the scx_lavd scheduler while gaming";
          bindsTo = [ "gaming.service" ];
          after = [ "gaming.service" ];
          serviceConfig.ExecStart = "${lib.getExe' pkgs.scx.rustscheds "scx_lavd"} --performance";
        };
        gaming-awake = {
          description = "Keep the laptop awake while gaming";
          bindsTo = [ "gaming.service" ];
          after = [ "gaming.service" ];
          serviceConfig.ExecStart = "${lib.getExe' config.systemd.package "systemd-inhibit"} --what=sleep --who=gaming --why=\"Steam on the eGPU\" ${lib.getExe' pkgs.coreutils "sleep"} infinity";
        };
        gaming-performance = {
          description = "Hold the performance power profile while gaming";
          bindsTo = [ "gaming.service" ];
          after = [ "gaming.service" ];
          serviceConfig.ExecStart = "${lib.getExe' config.services.power-profiles-daemon.package "powerprofilesctl"} launch --profile performance --reason Gaming --appid gaming -- ${lib.getExe' pkgs.coreutils "sleep"} infinity";
        };
      };
      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (action.id == "org.freedesktop.systemd1.manage-units" &&
              action.lookup("unit") == "gaming.service" &&
              subject.user == "marcos" && subject.local && subject.active) {
            return polkit.Result.YES;
          }
        });
      '';
      environment.systemPackages = [ gaming ];
      home-manager.users.marcos = {
        home.sessionVariables = {
          VK_DRIVER_FILES = "${pkgs.addDriverRunpath.driverLink}/share/vulkan/icd.d/intel_icd.x86_64.json";
          __EGL_VENDOR_LIBRARY_FILENAMES = "${pkgs.addDriverRunpath.driverLink}/share/glvnd/egl_vendor.d/50_mesa.json";
          __GLX_VENDOR_LIBRARY_NAME = "mesa";
        };
        wayland.windowManager.hyprland.settings.bind = [
          {
            _args = [
              "SUPER + G"
              (lib.generators.mkLuaInline "hl.dsp.exec_cmd(${lib.generators.toLua { } (lib.getExe gaming)})")
              { description = "Gaming mode"; }
            ];
          }
        ];
        programs.noctalia.settings.shell.session.actions = lib.mkAfter [
          {
            action = "command";
            command = lib.getExe gaming;
            label = "Gaming";
            shortcut = "6";
          }
        ];
      };
    };
}
