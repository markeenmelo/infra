{
  flake.modules.nixos.desktop = { config, lib, ... }: {
    services = {
      displayManager.noctalia-greeter = {
        enable = true;
        settings = {
          session.default = "Hyprland (UWSM)";
          keyboard.layout = "us";
          auth = {
            allow_empty_password = true;
            request_timeout = 60;
          };
        };
      };
      gnome.gnome-keyring.enable = true;
    };
    environment.persistence."/persist".directories = [
      {
        directory = "/var/lib/AccountsService";
        mode = "0700";
      }
      {
        directory = "/var/lib/noctalia-greeter";
        user = config.services.greetd.settings.default_session.user;
        group = config.users.users.${config.services.greetd.settings.default_session.user}.group;
        mode = "0750";
      }
    ];
    systemd.services.accounts-daemon.serviceConfig.StateDirectoryMode = lib.mkForce "0700";
  };

  flake.modules.homeManager.desktop =
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
        inherit settings;
      };
      xdg.configFile."noctalia/config.toml".target = "fleet-desktop/noctalia/config.toml";
      systemd.user.services.noctalia.Service.Environment = [
        "NOCTALIA_CONFIG_HOME=${config.xdg.configHome}/fleet-desktop"
        "NOCTALIA_STATE_HOME=${config.xdg.stateHome}/fleet-desktop"
        "NOCTALIA_DATA_HOME=${config.xdg.dataHome}/fleet-desktop"
      ];
    };
}
