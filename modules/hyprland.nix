{
  flake.modules.nixos.desktop = {
    programs.hyprland = {
      enable = true;
      withUWSM = true;
    };
    environment.sessionVariables.NIXOS_OZONE_WL = "1";
  };

  flake.modules.homeManager.desktop =
    {
      config,
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      inherit (config.lib.stylix) colors;
      lua = lib.generators.mkLuaInline;
      exec = command: lua "hl.dsp.exec_cmd(${lib.generators.toLua { } command})";
      app = command: exec "${lib.getExe pkgs.uwsm} app -- ${command}";
      noctalia = args: exec "${lib.getExe config.programs.noctalia.package} msg ${args}";
      ghostty = lib.getExe config.programs.ghostty.package;
      keybinds = pkgs.writeShellApplication {
        name = "hypr-keybinds";
        runtimeInputs = [
          osConfig.programs.hyprland.package
          pkgs.jq
          pkgs.less
          pkgs.util-linux
        ];
        text = ''
          hyprctl binds -j | jq -r '
            def bit($b): ((. / $b) | floor) % 2 == 1;
            def mods: [if bit(64) then "SUPER" else empty end, if bit(4) then "CTRL" else empty end,
                       if bit(8) then "ALT" else empty end, if bit(1) then "SHIFT" else empty end];
            .[] | select(.mouse | not)
            | [((.modmask | mods) + [.key] | join(" + ")),
               (if .has_description then .description else "\(.dispatcher) \(.arg)" end)]
            | @tsv' | sort -u | column -t -s "$(printf '\t')" | less -S
        '';
      };
      tailnetNext = pkgs.writeShellApplication {
        name = "tailnet-next";
        runtimeInputs = [
          osConfig.services.tailscale.package
          pkgs.jq
          pkgs.libnotify
        ];
        text = ''
          status=$(tailscale status --json)
          mapfile -t nodes < <(echo "$status" | jq -r '"direct", ([(.Peer // {})[] | select(.ExitNodeOption) | .HostName] | sort | .[])')
          current=$(echo "$status" | jq -r '[(.Peer // {})[] | select(.ExitNode) | .HostName][0] // "direct"')
          next=''${nodes[0]}
          for i in "''${!nodes[@]}"; do
            if [ "''${nodes[$i]}" = "$current" ]; then next=''${nodes[$(((i + 1) % ''${#nodes[@]}))]}; fi
          done
          if [ "$next" = direct ]; then
            tailscale set --exit-node=
          else
            tailscale set --exit-node="$next" --exit-node-allow-lan-access
          fi
          notify-send --app-name=tailscale "Exit node" "$next"
        '';
      };
      binds = {
        "SUPER + Space" = {
          desc = "App launcher";
          dsp = noctalia "panel-toggle launcher";
        };
        "SUPER + Return" = {
          desc = "Terminal";
          dsp = app ghostty;
        };
        "SUPER + E" = {
          desc = "Files";
          dsp = app (lib.getExe pkgs.nautilus);
        };
        "SUPER + B" = {
          desc = "Browser";
          dsp = app (lib.getExe config.programs.zen-browser.package);
        };
        "SUPER + CTRL + B" = {
          desc = "Bitwarden";
          dsp = app (lib.getExe pkgs.bitwarden-desktop);
        };
        "SUPER + CTRL + E" = {
          desc = "System monitor";
          dsp = app "${ghostty} -e ${lib.getExe pkgs.btop}";
        };
        "SUPER + T" = {
          desc = "Next exit node";
          dsp = exec (lib.getExe tailnetNext);
        };
        "SUPER + slash" = {
          desc = "Show keybinds";
          dsp = app "${ghostty} --class=hypr.keybinds -e ${lib.getExe keybinds}";
        };
        "SUPER + N" = {
          desc = "Control center";
          dsp = noctalia "panel-toggle control-center";
        };
        "SUPER + Escape" = {
          desc = "Session menu";
          dsp = noctalia "panel-toggle session";
        };
        "SUPER + period" = {
          desc = "Emoji picker";
          dsp = noctalia "panel-toggle launcher /emo";
        };
        "SUPER + comma" = {
          desc = "Noctalia settings";
          dsp = noctalia "settings-toggle";
        };
        "SUPER + Q" = {
          desc = "Close window";
          dsp = lua "hl.dsp.window.close()";
        };
        "SUPER + F" = {
          desc = "Fullscreen";
          dsp = lua "hl.dsp.window.fullscreen()";
        };
        "ALT + Tab" = {
          desc = "Window switcher";
          dsp = noctalia "window-switcher hold";
        };
        "SUPER + SHIFT + L" = {
          desc = "Lock screen";
          dsp = noctalia "session lock";
        };
        "Print" = {
          desc = "Screenshot region";
          dsp = noctalia "screenshot-region";
        };
        "SHIFT + Print" = {
          desc = "Screenshot screen";
          dsp = noctalia "screenshot-fullscreen";
        };
        "SUPER + Print" = {
          desc = "Screenshot and annotate";
          dsp = noctalia "screenshot-annotate";
        };
      };
      moves = lib.listToAttrs (
        map
          (
            direction:
            lib.nameValuePair "SUPER + SHIFT + ${direction}" {
              desc = "Move window ${direction}";
              dsp = lua "hl.dsp.window.move({ direction = ${lib.generators.toLua { } direction} })";
            }
          )
          [
            "left"
            "right"
            "up"
            "down"
          ]
      );
    in
    {
      home.packages = [
        pkgs.brightnessctl
        pkgs.playerctl
      ];
      wayland.windowManager.hyprland = {
        enable = true;
        package = null;
        portalPackage = null;
        systemd.enable = false;
        extraLuaFiles.stock = "${osConfig.programs.hyprland.package}/share/hypr/hyprland.lua";
        importantPrefixes = lib.mkOptionDefault [ "unbind" ];
        extraConfig = ''
          hl.animation({ leaf = "global", enabled = true, speed = 1.5, bezier = "default" })
          hl.animation({ leaf = "windows", enabled = true, speed = 1.5, bezier = "default", style = "slide" })
          hl.animation({ leaf = "workspaces", enabled = true, speed = 1.5, bezier = "default", style = "slide" })
        '';
        settings = {
          config = {
            general = {
              gaps_in = 4;
              gaps_out = 6;
              border_size = 2;
              "col.active_border" = lib.mkForce "rgb(${colors.base0D})";
              "col.inactive_border" = lib.mkForce "rgb(${colors.base02})";
            };
            decoration = {
              rounding = 6;
              blur.enabled = false;
              shadow.enabled = false;
            };
            input = {
              repeat_rate = 40;
              repeat_delay = 300;
              touchpad = {
                natural_scroll = true;
                clickfinger_behavior = true;
                scroll_factor = 0.5;
              };
            };
            misc = {
              disable_hyprland_logo = true;
              force_default_wallpaper = 0;
            };
          };
          monitor = [
            {
              output = "";
              position = "auto-center-up";
              mode = "highres";
              scale = 1;
              vrr = 1;
            }
          ];
          window_rule = [
            {
              name = "file-picker";
              match.class = "^xdg-desktop-portal-gtk$";
              float = true;
              center = true;
              size = [
                1100
                700
              ];
            }
            {
              name = "picture-in-picture";
              match.title = "^Picture-in-Picture$";
              float = true;
              pin = true;
              keep_aspect_ratio = true;
              size = [
                640
                360
              ];
              move = [
                "monitor_w-window_w-24"
                "monitor_h-window_h-24"
              ];
            }
            {
              name = "utilities";
              match.class = "^(org\\.gnome\\.FileRoller|org\\.gnome\\.Loupe)$";
              float = true;
              center = true;
            }
            {
              name = "keybinds";
              match.class = "^hypr\\.keybinds$";
              float = true;
              center = true;
              size = [
                900
                700
              ];
            }
            {
              name = "bitwarden";
              match.class = "^bitwarden$";
              float = true;
              center = true;
            }
            {
              name = "telegram-media";
              match = {
                class = "^org\\.telegram\\.desktop$";
                title = "^Media viewer$";
              };
              float = true;
              center = true;
            }
          ];
          unbind = map (key: { _args = [ key ]; }) [
            "SUPER + Q"
            "SUPER + R"
            "SUPER + E"
          ];
          bind =
            lib.concatMap
              (lib.mapAttrsToList (
                key: bind: {
                  _args = [
                    key
                    bind.dsp
                    { description = bind.desc; }
                  ];
                }
              ))
              [
                binds
                moves
              ];
        };
      };
      xdg.configFile."uwsm/env".text =
        ". ${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";
    };
}
