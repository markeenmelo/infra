{
  # Contribute shell state/config to the same desktop value on both tracks. The
  # stable Home Manager pin has no programs.noctalia module; these ordinary HM
  # interfaces need neither an upstream module backport nor another package set.
  flake.modules.homeManager.hyprland =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      settings = {
        shell = {
          polkit_agent = true;
          launch_apps_as_systemd_services = true;
          telemetry_enabled = false;
          offline_mode = true;
          clipboard_enabled = false;
        };
        theme = {
          mode = "dark";
          source = "builtin";
          builtin = "Catppuccin";
          templates = {
            enable_builtin_templates = false;
            enable_community_templates = false;
          };
        };
        # No external wallpaper path, downloaded plugin, location or ICC is guessed.
        wallpaper.enabled = false;
        bar.main = {
          position = "top";
          auto_hide = true;
          start = [
            "launcher"
            "workspaces"
          ];
          center = [ "clock" ];
          end = [
            "privacy"
            "tray"
            "network"
            "volume"
            "brightness"
            "battery"
            "notifications"
            "control-center"
          ];
        };
        notification.enable_daemon = true;
        lockscreen = {
          enabled = true;
          allow_empty_password = false;
          fingerprint = false;
          lock_before_suspend = true;
        };
        idle.behavior = {
          lock = {
            enabled = true;
            timeout = 300;
            action = "lock";
          };
          screen-off = {
            enabled = true;
            timeout = 360;
            action = "screen_off";
          };
        };
      };
      rawConfig = (pkgs.formats.toml { }).generate "noctalia-config.toml" settings;
    in
    {
      home.packages = [ pkgs.noctalia ];
      xdg.configFile."fleet-desktop/noctalia/config.toml".source =
        pkgs.runCommand "noctalia-checked-config.toml" { }
          ''
            export HOME="$TMPDIR/home"
            export XDG_STATE_HOME="$HOME/.local/state"
            mkdir -p "$HOME"
            if ! ${lib.getExe pkgs.noctalia} config validate ${rawConfig} > validation.log 2>&1; then
              cat validation.log
              exit 1
            fi
            cat validation.log
            # Upstream exits zero for warnings, including ignored/obsolete settings.
            if grep -E 'WARN|ERROR' validation.log; then
              exit 1
            fi
            cp ${rawConfig} "$out"
          '';
      systemd.user.services.noctalia = {
        Unit = {
          Description = "Noctalia desktop shell, lock screen and idle manager";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = lib.getExe pkgs.noctalia;
          # A new profile: old GUI overrides, plugins and source fragments must
          # not bleed into this desktop. Do not redirect child applications' XDG.
          Environment = [
            "NOCTALIA_CONFIG_HOME=${config.xdg.configHome}/fleet-desktop"
            "NOCTALIA_STATE_HOME=${config.xdg.stateHome}/fleet-desktop"
            "NOCTALIA_DATA_HOME=${config.xdg.dataHome}/fleet-desktop"
          ];
          Restart = "on-failure";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
      # /home is already durable on ThinkPad; no duplicate impermanence binds.
      # Future GUI changes in this profile's state still override the TOML base.
      # Existing Noctalia directories are neither read nor deleted by this service.
    };
}
