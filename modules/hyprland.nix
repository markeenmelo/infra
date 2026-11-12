{
  flake.modules.nixos.desktop =
    { lib, ... }:
    {
      options.fleet = {
        internalDisplay = lib.mkOption {
          type = lib.types.str;
          description = "The laptop's built-in panel as Hyprland names it; hidden while the lid is shut and another display is connected.";
        };
        lidSwitch = lib.mkOption {
          type = lib.types.str;
          description = "The lid's switch as Hyprland names it (`hyprctl devices`), which reapplies the monitor rules when it moves.";
        };
      };
      config.programs.hyprland = {
        enable = true;
        withUWSM = true;
      };
      config.environment.sessionVariables.NIXOS_OZONE_WL = "1";
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
          trap 'notify-send --app-name=tailscale "Exit node" "switch failed"' ERR
          status=$(tailscale status --json)
          mapfile -t nodes < <(echo "$status" | jq -r '"direct", ([(.Peer // {})[] | select(.ExitNodeOption and .Online) | .DNSName | split(".")[0]] | sort | .[])')
          current=$(echo "$status" | jq -r '[(.Peer // {})[] | select(.ExitNode) | .DNSName | split(".")[0]][0] // "direct"')
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
      media = {
        "XF86AudioRaiseVolume" = {
          desc = "Volume up";
          dsp = noctalia "volume-up";
          repeating = true;
        };
        "XF86AudioLowerVolume" = {
          desc = "Volume down";
          dsp = noctalia "volume-down";
          repeating = true;
        };
        "XF86AudioMute" = {
          desc = "Mute";
          dsp = noctalia "volume-mute";
        };
        "XF86AudioMicMute" = {
          desc = "Mute microphone";
          dsp = noctalia "mic-mute";
        };
        "XF86MonBrightnessUp" = {
          desc = "Brightness up";
          dsp = noctalia "brightness-up";
          repeating = true;
        };
        "XF86MonBrightnessDown" = {
          desc = "Brightness down";
          dsp = noctalia "brightness-down";
          repeating = true;
        };
        "XF86AudioPlay" = {
          desc = "Play or pause";
          dsp = noctalia "media toggle";
        };
        "XF86AudioPause" = {
          desc = "Play or pause";
          dsp = noctalia "media toggle";
        };
        "XF86AudioNext" = {
          desc = "Next track";
          dsp = noctalia "media next";
        };
        "XF86AudioPrev" = {
          desc = "Previous track";
          dsp = noctalia "media previous";
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
      wayland.windowManager.hyprland = {
        enable = true;
        package = null;
        portalPackage = null;
        systemd.enable = false;
        extraLuaFiles.stock = "${osConfig.programs.hyprland.package}/share/hypr/hyprland.lua";
        extraLuaFiles.lid = ''
          local internal = ${lib.generators.toLua { } osConfig.fleet.internalDisplay}
          function lid_shut_docked()
            local p = io.popen("${lib.getExe' osConfig.systemd.package "busctl"} get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager LidClosed")
            if not p then return false end
            local shut = p:read("a"):find("true") ~= nil
            p:close()
            if not shut then return false end
            for _, m in ipairs(hl.get_monitors()) do
              if m.name ~= internal and m.name ~= "FALLBACK" then return true end
            end
            return false
          end
          local reload = "${lib.getExe' osConfig.programs.hyprland.package "hyprctl"} reload"
          hl.bind(${
            lib.generators.toLua { } "switch:${osConfig.fleet.lidSwitch}"
          }, hl.dsp.exec_cmd(reload), { locked = true })
          for _, event in ipairs({ "monitor.added", "monitor.removed" }) do
            hl.on(event, function(m)
              if m.name ~= internal and m.name ~= "FALLBACK" then hl.exec_cmd(reload) end
            end)
          end
        '';
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
              blur = {
                enabled = true;
                size = 6;
                passes = 2;
              };
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
            {
              output = "desc:Dell Inc. DELL U3423WE 4TSGMP3";
              position = "auto-center-up";
              mode = "3440x1440@59.97";
              scale = 1;
            }
          ];
          layer_rule = [
            {
              name = "noctalia-blur";
              match.namespace = "^noctalia-(bar-.+|notification|panel|attached-panel|osd)$";
              ignore_alpha = 0.5;
              blur = true;
              blur_popups = true;
            }
          ];
          window_rule =
            lib.mapAttrsToList
              (class: workspace: {
                name = "workspace-${class}";
                match.class = "^${lib.escapeRegex class}$";
                inherit workspace;
              })
              {
                "zen-beta" = "1";
                "com.mitchellh.ghostty" = "2";
                "dev.zed.Zed" = "2";
                "org.telegram.desktop" = "4";
                "com.github.dagmoller.whatsapp-electron" = "4";
              }
            ++ [
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
                name = "zen-extension-popout";
                match = {
                  class = "^zen-beta$";
                  title = "^Extension: \\(";
                };
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
          unbind = map (key: { _args = [ key ]; }) (
            [
              "SUPER + Q"
              "SUPER + R"
              "SUPER + E"
            ]
            ++ lib.attrNames media
          );
          bind =
            lib.concatMap
              (lib.mapAttrsToList (
                key: bind: {
                  _args = [
                    key
                    bind.dsp
                    {
                      description = bind.desc;
                      locked = lib.hasPrefix "XF86" key;
                      repeating = bind.repeating or false;
                    }
                  ];
                }
              ))
              [
                binds
                moves
                media
              ];
        };
      };
      xdg.configFile."uwsm/env".text =
        ". ${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";
    };
}
