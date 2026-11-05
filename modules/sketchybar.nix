{
  flake.modules.darwin.desktop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (config.lib.stylix) colors;
      font = config.stylix.fonts.monospace.name;
      workspaces = map (lib.removePrefix "workspace ") (
        lib.filter (lib.hasPrefix "workspace ") (
          lib.attrValues config.services.aerospace.settings.mode.main.binding
        )
      );
      space = pkgs.writeShellScript "sketchybar-space" ''
        if [ "''${NAME#space.}" = "''${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused)}" ]; then
          sketchybar --set "$NAME" label.color=0xff${colors.base00} background.drawing=on
        else
          sketchybar --set "$NAME" label.color=0xff${colors.base05} background.drawing=off
        fi
      '';
      battery = pkgs.writeShellScript "sketchybar-battery" ''
        sketchybar --set "$NAME" label="$(pmset -g batt | grep -Eo '[0-9]+%')"
      '';
      agenda = pkgs.writeShellScript "sketchybar-agenda" ''
        sketchybar --set "$NAME" label="$(${config.homebrew.prefix}/bin/icalBuddy -n -li 1 -nc -b "" -ps "| |" -iep datetime,title -po datetime,title -tf %H:%M -df "" eventsToday | head -1)"
      '';
    in
    {
      system.defaults.NSGlobalDomain._HIHideMenuBar = true;
      homebrew.brews = [ "ical-buddy" ];
      services.sketchybar = {
        enable = true;
        extraPackages = [ config.services.aerospace.package ];
        config = ''
          sketchybar --bar height=32 position=top sticky=on color=0xff${colors.base00} padding_left=8 padding_right=8
          sketchybar --default label.font="${font}:Bold:13.0" label.color=0xff${colors.base05} padding_left=4 padding_right=4 \
            background.color=0xff${colors.base0D} background.corner_radius=4 background.height=22 background.drawing=off
          sketchybar --add event aerospace_workspace_change
          for n in ${lib.concatStringsSep " " workspaces}; do
            sketchybar --add item "space.$n" left \
              --subscribe "space.$n" aerospace_workspace_change \
              --set "space.$n" label="$n" label.padding_left=8 label.padding_right=8 \
                click_script="aerospace workspace $n" script="${space}"
          done
          sketchybar --add item front_app left --subscribe front_app front_app_switched \
            --set front_app script='sketchybar --set "$NAME" label="$INFO"'
          sketchybar --add item clock right --set clock update_freq=10 \
            script='sketchybar --set "$NAME" label="$(date "+%a %d %b %H:%M")"'
          sketchybar --add item battery right --subscribe battery system_woke power_source_change \
            --set battery update_freq=120 script="${battery}"
          sketchybar --add item agenda right --set agenda update_freq=300 script="${agenda}"
          sketchybar --update
        '';
      };
    };
}
