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
        tailscale.extraSetFlags = [ "--operator=marcos" ];
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

  flake.modules.homeManager.desktop =
    {
      config,
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      systemd = osConfig.systemd.package;
    in
    {
      programs.noctalia = {
        enable = true;
        systemd.enable = true;
        settings = {
          shell = {
            clipboard_enabled = false;
            popup_shadows = false;
          };
          bar.default = {
            margin_ends = 0;
            margin_edge = 0;
            thickness = lib.mkDefault 32;
            font_family = config.stylix.fonts.monospace.name;
            font_weight = 700;
            background_opacity = config.stylix.opacity.desktop;
            radius = 0;
            capsule_radius = 4;
            shadow = false;
            start = [
              "workspaces"
              "active_window"
              "media"
            ];
            center = [ ];
            end = [
              "tray"
              "agenda"
              "pull_requests"
              "claude"
              "tailnet"
              "network"
              "bluetooth"
              "volume"
              "battery"
              "notifications"
              "session"
              "weather"
              "clock"
            ];
          };
          widget = {
            clock.format = "{:%a %d %b %H:%M}";
            active_window.max_length = 200;
            media = {
              hide_when_no_media = true;
              max_length = 160;
            };
            weather.show_condition = false;
            network.show_label = false;
            tailnet.type = "rylos/tailnet:bar";
            agenda.type = "yuta/meeting-bar:bar";
            pull_requests.type = "raycursive/github-prs:bar";
            claude.type = "jrohland/claudecode:pill";
          };
          weather = {
            enabled = true;
            unit = "metric";
          };
          location.auto_locate = true;
          calendar = {
            enabled = true;
            account.google = {
              type = "google";
              name = "Google";
            };
          };
          plugin_settings."yuta/meeting-bar".title_length = 16;
          plugins = {
            enabled = [
              "jrohland/claudecode"
              "raycursive/github-prs"
              "rylos/tailnet"
              "yuta/meeting-bar"
            ];
            source = [
              {
                name = "pinned";
                kind = "path";
                location = "${pkgs.callPackage ./noctalia-plugins.pkg.nix { }}";
                enabled = true;
              }
            ];
          };
          lockscreen.transition = [ ];
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
              command = "${lib.getExe' systemd "systemd-ac-power"} || ${lib.getExe' systemd "systemctl"} suspend";
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
