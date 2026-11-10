let
  exitNode =
    pkgs: tailscale:
    pkgs.writeShellApplication {
      name = "tailnet-exit-node";
      runtimeInputs = [
        tailscale
        pkgs.jq
      ];
      text = ''
        node=$1
        if [ "$node" = direct ]; then
          exec tailscale set --exit-node=
        fi
        if ! tailscale status --json | jq -e --arg node "$node" '[(.Peer // {})[] | select(.ExitNodeOption and .Online) | .DNSName | split(".")[0]] | index($node)' > /dev/null; then
          echo "not an online exit node: $node" >&2
          exit 1
        fi
        exec tailscale set --exit-node="$node" --exit-node-allow-lan-access
      '';
    };
in
{
  flake.modules.nixos.desktop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
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
      config.security.sudo.extraRules = [
        {
          users = [ "marcos" ];
          runAs = "root";
          commands = [
            {
              command = "${lib.getExe (exitNode pkgs config.services.tailscale.package)} ^[a-z0-9-]+$";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];
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
          ${osConfig.security.wrapperDir}/sudo -n ${lib.getExe (exitNode pkgs osConfig.services.tailscale.package)} "$next"
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
