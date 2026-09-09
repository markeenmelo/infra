{
  # Native unstable Home Manager owns Noctalia configuration and its one service.
  flake.modules.homeManager.hyprland =
    {
      config,
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
          fingerprint = true;
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
    in
    {
      programs.noctalia = {
        enable = true;
        systemd.enable = true;
        checkConfig = true;
        inherit settings;
      };
      # Keep native generation/validation, but retain the isolated fresh shell
      # profile. Existing app preferences are reused only by their own modules.
      xdg.configFile."noctalia/config.toml".target = "fleet-desktop/noctalia/config.toml";
      systemd.user.services.noctalia.Service.Environment = [
        "NOCTALIA_CONFIG_HOME=${config.xdg.configHome}/fleet-desktop"
        "NOCTALIA_STATE_HOME=${config.xdg.stateHome}/fleet-desktop"
        "NOCTALIA_DATA_HOME=${config.xdg.dataHome}/fleet-desktop"
      ];
      # /home is already durable on ThinkPad; no duplicate impermanence binds.
      # Future GUI changes in this profile's state still override the TOML base.
      # Existing Noctalia directories are neither read nor deleted by this service.
    };
}
