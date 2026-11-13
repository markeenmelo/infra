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
      cardUnit = "dev-dri-egpu.device";
      systemctl = lib.getExe' config.systemd.package "systemctl";
      handover = pkgs.writeShellApplication {
        name = "gaming-handover";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.ddcutil
          pkgs.gawk
        ];
        text = ''
          inputs=
          case $1 in
            on)
              for connector in /sys/class/drm/card*-*; do
                if [ -e "$connector/ddc" ] && grep -qa ${lib.escapeShellArg monitor} "$connector/edid" 2>/dev/null; then
                  bus=$(basename "$(readlink "$connector/ddc")")
                  bus=''${bus#i2c-}
                  previous=$(ddcutil --bus "$bus" --terse getvcp 60 | awk '{ print "0" $NF }' || true)
                  inputs+="$bus ''${previous:-${displayPort}}"$'\n'
                  ddcutil --bus "$bus" --noverify setvcp 60 ${displayPort} || true
                fi
              done
              printf %s "$inputs" > ${flag}
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
              for _ in 1 2 3 4 5; do
                if ddcutil --bus "$bus" --noverify setvcp 60 "$previous"; then break; fi
                sleep 1
              done
            done <<< "$inputs"
          fi
        '';
      };
      gaming = pkgs.writeShellApplication {
        name = "gaming";
        runtimeInputs = [ pkgs.libnotify ];
        text = ''
          if ${systemctl} is-active --quiet gaming.service; then
            ${systemctl} stop gaming.service
          elif [ -e ${card} ]; then
            ${systemctl} start gaming.service
          else
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
          extraPackages = [
            (pkgs.writeShellScriptBin "steamos-session-select" "exec ${systemctl} stop --no-block gaming.service")
          ];
        };
      };
      services.udev.packages = [
        (pkgs.writeTextDir "etc/udev/rules.d/72-gaming.rules" ''
          SUBSYSTEM=="pci", ATTR{vendor}=="${nvidia}", ENV{ID_SEAT}="${seat}"
          ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="${nvidia}", ATTR{class}=="0x03*", RUN{builtin}+="kmod load nvidia_drm"
          SUBSYSTEM=="drm", ENV{DEVTYPE}=="drm_minor", KERNEL=="card[0-9]*", ATTRS{vendor}=="${nvidia}", SYMLINK+="${lib.removePrefix "/dev/" card}", TAG+="systemd"
          SUBSYSTEM=="input", ATTRS{idVendor}=="${keychron}", TEST=="${flag}", ENV{ID_SEAT}="${seat}"
        '')
      ];
      systemd.services = {
        gaming = {
          description = "Steam Big Picture on the eGPU";
          bindsTo = [ cardUnit ];
          after = [
            cardUnit
            "systemd-user-sessions.service"
          ];
          wants = [ "gaming-awake.service" ];
          environment = {
            XDG_SEAT = seat;
            XDG_SESSION_TYPE = "wayland";
            XDG_SESSION_CLASS = "user";
          };
          serviceConfig = {
            User = "marcos";
            PAMName = "login";
            ExecStartPre = "+${lib.getExe handover} on";
            ExecStart = "${lib.getExe config.programs.gamescope.package} --steam --prefer-vk-device ${rtx3070} --adaptive-sync --hdr-enabled -- ${lib.getExe config.programs.steam.package} -gamepadui -steamos3 -pipewire-dmabuf";
            ExecStopPost = "+${lib.getExe handover} off";
            # shortcut: gamescope 3.17 hangs 25 s releasing the card through logind and then crashes, so stop kills it outright; drop when it exits cleanly
            KillSignal = "SIGKILL";
          };
        };
        gaming-awake = {
          description = "Keep the laptop awake while gaming";
          bindsTo = [ "gaming.service" ];
          after = [ "gaming.service" ];
          serviceConfig.ExecStart = "${lib.getExe' config.systemd.package "systemd-inhibit"} --what=sleep --who=gaming --why=\"Steam on the eGPU\" ${lib.getExe' pkgs.coreutils "sleep"} infinity";
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
