{
  flake.modules.darwin.desktop =
    { config, lib, ... }:
    let
      sketchybar = lib.getExe config.services.sketchybar.package;
      directions = [
        "left"
        "down"
        "up"
        "right"
      ];
      workspaces = map toString (lib.range 1 9);
    in
    {
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
          exec-on-workspace-change = [
            "/bin/bash"
            "-c"
            "${sketchybar} --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE"
          ];
          mode.main.binding = lib.mkMerge [
            (lib.genAttrs' directions (dir: lib.nameValuePair "alt-${dir}" "focus ${dir}"))
            (lib.genAttrs' directions (dir: lib.nameValuePair "alt-shift-${dir}" "move ${dir}"))
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
            }
          ];
        };
      };
    };
}
