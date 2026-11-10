{
  flake.modules.nixos.desktop =
    { config, ... }:
    {
      services = {
        displayManager.noctalia-greeter = {
          enable = true;
          settings.session.default = "Hyprland (uwsm-managed)";
          cursorTheme = { inherit (config.stylix.cursor) package name; };
          passwordlessSyncUsers = [ "marcos" ];
        };
        gnome.gnome-keyring.enable = true;
      };
      systemd.services.accounts-daemon.serviceConfig.StateDirectoryMode = "0700";
      preservation.preserveAt."/persist".directories = [
        {
          directory = "/var/lib/AccountsService";
          mode = "0700";
        }
        "/var/lib/noctalia-greeter"
      ];
    };

  flake.modules.homeManager.desktop = {
    programs.noctalia = {
      enable = true;
      systemd.enable = true;
      settings = {
        shell.clipboard_enabled = false;
        bar.default = {
          margin_ends = 0;
          margin_edge = 0;
          start = [
            "session"
            "workspaces"
            "media"
          ];
          center = [ ];
          end = [
            "tray"
            "volume"
            "brightness"
            "bluetooth"
            "battery"
            "network"
            "control-center"
            "notifications"
            "clock"
          ];
        };
        nightlight.enabled = true;
        idle.behavior = {
          lock = {
            timeout = 300;
            action = "lock";
          };
          screen-off = {
            timeout = 330;
            locked_timeout = 30;
            action = "screen_off";
          };
          suspend-battery = {
            timeout = 600;
            action = "command";
            command = "systemd-ac-power || systemctl suspend";
          };
          suspend = {
            timeout = 1800;
            action = "lock_and_suspend";
          };
        };
      };
    };
    systemd.user.services.noctalia.Unit.X-RestartIfChanged = false;
  };
}
