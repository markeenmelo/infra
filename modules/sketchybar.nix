{ config, ... }:
let
  inherit (config.fleet) domain;
in
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
      jq = lib.getExe pkgs.jq;
      battery = pkgs.writeShellScript "sketchybar-battery" ''
        batt=$(pmset -g batt)
        case "$batt" in
          *"AC Power"*) icon=󰂄 ;;
          *) icon=󰁹 ;;
        esac
        sketchybar --set "$NAME" icon="$icon" label="$(echo "$batt" | grep -Eo '[0-9]+%')"
      '';
      volume = pkgs.writeShellScript "sketchybar-volume" ''
        level=''${INFO:-$(osascript -e 'output volume of (get volume settings)')}
        if [ "$level" = 0 ]; then icon=󰝟; else icon=󰕾; fi
        sketchybar --set "$NAME" icon="$icon" label="$level%"
      '';
      network = pkgs.writeShellScript "sketchybar-network" ''
        wifi=$(networksetup -listallhardwareports | awk '/Wi-Fi/ { getline; print $2 }')
        if [ -n "$wifi" ] && ipconfig getifaddr "$wifi" >/dev/null; then
          icon=󰖩
        elif route -n get default >/dev/null 2>&1; then
          icon=󰈀
        else
          icon=󰖪
        fi
        sketchybar --set "$NAME" icon="$icon"
      '';
      tailnet = pkgs.writeShellScript "sketchybar-tailnet" ''
        status=$(${lib.getExe config.services.tailscale.package} status --json 2>/dev/null)
        if [ "$(echo "$status" | ${jq} -r .BackendState)" != Running ]; then
          sketchybar --set "$NAME" icon.color=0xff${colors.base03} label=off
        else
          exit=$(echo "$status" | ${jq} -r '[(.Peer // {})[] | select(.ExitNode) | .HostName][0] // "direct"')
          sketchybar --set "$NAME" icon.color=0xff${colors.base05} label="$exit"
        fi
      '';
      alerts = pkgs.writeShellScript "sketchybar-alerts" ''
        if ! response=$(printf 'Authorization: Bearer %s\n' "$(cat ${config.sops.secrets.grafana-mcp-token.path})" \
          | curl -fsS --max-time 10 -H @- "https://grafana.${domain}/api/alertmanager/grafana/api/v2/alerts?active=true&silenced=false&inhibited=false") \
          || ! severities=$(echo "$response" | ${jq} -r '.[].labels.severity'); then
          sketchybar --set "$NAME" drawing=on icon.color=0xff${colors.base03} label="?"
          exit
        fi
        critical=$(echo "$severities" | grep -c '^critical$')
        warning=$(echo "$severities" | grep -c '^warning$')
        if [ "$critical" -gt 0 ]; then
          sketchybar --set "$NAME" drawing=on icon.color=0xff${colors.base08} label=$((critical + warning))
        elif [ "$warning" -gt 0 ]; then
          sketchybar --set "$NAME" drawing=on icon.color=0xff${colors.base0A} label="$warning"
        else
          sketchybar --set "$NAME" drawing=off
        fi
      '';
      spotify = pkgs.writeShellScript "sketchybar-spotify" ''
        if [ "$(echo "$INFO" | ${jq} -r '."Player State"')" = Playing ]; then
          sketchybar --set "$NAME" drawing=on label="$(echo "$INFO" | ${jq} -r '"\(.Artist) - \(.Name)"' | cut -c1-40)"
        else
          sketchybar --set "$NAME" drawing=off
        fi
      '';
      load = pkgs.writeShellScript "sketchybar-load" ''
        cpu=$(ps -A -o %cpu | awk -v n="$(getconf _NPROCESSORS_ONLN)" '{ s += $1 } END { printf "%.0f", s / n }')
        mem=$(memory_pressure | awk '/free percentage/ { gsub("%", "", $5); print 100 - $5 }')
        sketchybar --set cpu label="$cpu%" --set memory label="$mem%"
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
          sketchybar --bar height=32 position=top sticky=on color=0xe6${colors.base00} blur_radius=20 padding_left=8 padding_right=8
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
          sketchybar --default icon.font="${font}:Bold:15.0" icon.color=0xff${colors.base05} icon.padding_right=4
          sketchybar --add event spotify_change com.spotify.client.PlaybackStateChanged
          sketchybar --add item spotify left --subscribe spotify spotify_change \
            --set spotify drawing=off icon=󰎆 label.color=0xff${colors.base03} script="${spotify}"
          sketchybar --add item battery right --subscribe battery system_woke power_source_change \
            --set battery update_freq=120 script="${battery}"
          sketchybar --add item volume right --subscribe volume volume_change --set volume script="${volume}"
          sketchybar --add item network right --subscribe network wifi_change system_woke \
            --set network update_freq=60 label.drawing=off script="${network}"
          sketchybar --add item tailnet right --subscribe tailnet system_woke \
            --set tailnet update_freq=30 icon=󰦝 script="${tailnet}"
          sketchybar --add item memory right --set memory icon=󰍛
          sketchybar --add item cpu right --set cpu icon=󰻠 update_freq=10 script="${load}"
          sketchybar --add item alerts right --subscribe alerts system_woke \
            --set alerts drawing=off update_freq=60 icon=󰂚 script="${alerts}"
          sketchybar --add item agenda right --set agenda update_freq=300 script="${agenda}"
          sketchybar --update
        '';
      };
    };
}
