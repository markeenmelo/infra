{
  flake.modules.darwin.desktop =
    { config, lib, ... }:
    let
      sketchybar = lib.getExe config.services.sketchybar.package;
      directions = {
        h = "left";
        j = "down";
        k = "up";
        l = "right";
      };
      workspaces = map toString (lib.range 1 4);
    in
    {
      services.jankyborders = {
        enable = true;
        active_color = "0xff${config.lib.stylix.colors.base0D}";
        inactive_color = "0xff${config.lib.stylix.colors.base02}";
        width = 2.0;
        style = "round";
        hidpi = true;
      };
      services.aerospace = {
        enable = true;
        settings = {
          gaps = {
            inner = {
              horizontal = 8;
              vertical = 8;
            };
            outer = {
              left = 6;
              right = 6;
              top = [
                { monitor.built-in = 6; }
                38
              ];
              bottom = 6;
            };
          };
          on-window-detected =
            lib.mapAttrsToList
              (app-id: workspace: {
                "if" = { inherit app-id; };
                run = "move-node-to-workspace ${workspace}";
              })
              {
                "app.zen-browser.zen" = "1";
                "com.mitchellh.ghostty" = "2";
                "dev.zed.Zed" = "2";
                "com.spotify.client" = "3";
                "ru.keepcoder.Telegram" = "4";
                "net.whatsapp.WhatsApp" = "4";
              }
            ++
              map
                (app-id: {
                  "if" = { inherit app-id; };
                  run = "layout floating";
                })
                [
                  "com.bitwarden.desktop"
                  "com.apple.systempreferences"
                ];
          on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];
          exec-on-workspace-change = [
            "/bin/bash"
            "-c"
            "${sketchybar} --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE"
          ];
          mode.main.binding = lib.mkMerge [
            (lib.mapAttrs' (key: dir: lib.nameValuePair "alt-${key}" "focus ${dir}") directions)
            (lib.mapAttrs' (key: dir: lib.nameValuePair "alt-shift-${key}" "move ${dir}") directions)
            (lib.genAttrs' workspaces (n: lib.nameValuePair "alt-${n}" "workspace ${n}"))
            (lib.genAttrs' workspaces (n: lib.nameValuePair "alt-shift-${n}" "move-node-to-workspace ${n}"))
            {
              alt-minus = "resize smart -50";
              alt-equal = "resize smart +50";
              alt-f = "fullscreen";
              alt-v = "layout floating tiling";
              alt-slash = "layout tiles horizontal vertical";
              alt-q = "close";
              alt-enter = "exec-and-forget /usr/bin/open -na /Applications/Ghostty.app";
              alt-tab = "workspace-back-and-forth";
              alt-comma = "focus-monitor --wrap-around prev";
              alt-period = "focus-monitor --wrap-around next";
              alt-shift-comma = "move-node-to-monitor --wrap-around --focus-follows-window prev";
              alt-shift-period = "move-node-to-monitor --wrap-around --focus-follows-window next";
              alt-ctrl-comma = "move-workspace-to-monitor --wrap-around prev";
              alt-ctrl-period = "move-workspace-to-monitor --wrap-around next";
            }
          ];
        };
      };
    };
}
