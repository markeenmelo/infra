{
  flake.modules.nixos.desktop =
    { config, lib, ... }:
    let
      outputs = config.home-manager.users.marcos.programs.umbriel.settings.output;
      placed = lib.filterAttrs (_: output: output ? position) outputs;
      scaled = lib.filterAttrs (_: output: output ? scale) outputs;
      shift =
        axis: -(lib.foldl' lib.min 0 (lib.mapAttrsToList (_: o: lib.elemAt o.position axis) placed));
      entries =
        attrs: f:
        lib.concatStringsSep "; " (lib.mapAttrsToList (name: output: "${name}:${f output}") attrs);
    in
    {
      services = {
        displayManager.noctalia-greeter = {
          enable = true;
          settings = {
            session.default = "Umbriel";
            user.default = "marcos";
            appearance = {
              wallpaper = {
                path = "${config.stylix.image}";
                fill_mode = "crop";
              };
              font_family = config.stylix.fonts.sansSerif.name;
              hide_logo = true;
              scheme_selector_position = "hidden";
            };
            clock = {
              time_format = "{:%H:%M}";
              date_format = "%a %d %b";
            };
            output = {
              layout = entries placed (
                output:
                "${toString (lib.elemAt output.position 0 + shift 0)},${
                  toString (lib.elemAt output.position 1 + shift 1)
                }"
              );
              scales = lib.mkIf (scaled != { }) (entries scaled (output: toString output.scale));
            };
            idle.timeout = 60;
            keyboard.numlock = true;
          };
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
      onBattery = "${lib.getExe' osConfig.systemd.package "systemd-ac-power"} ||";
      umbriel = lib.getExe osConfig.programs.umbriel.package;
    in
    {
      programs.noctalia = {
        enable = true;
        systemd.enable = true;
        settings = {
          shell = {
            session.actions =
              lib.imap1
                (index: action: {
                  inherit action;
                  shortcut = toString index;
                })
                [
                  "lock"
                  "logout"
                  "lock_and_suspend"
                  "reboot"
                  "shutdown"
                ];
            polkit_agent = true;
            launch_apps_as_systemd_services = true;
            clipboard_enabled = false;
            umbriel_overview_type_to_launch_enabled = true;
            umbriel_overview_close_on_launch_enabled = true;
            popup_shadows = false;
            panel = {
              open_near_click_control_center = true;
              open_near_click_session = true;
            };
          };
          bar.default = {
            margin_ends = 0;
            margin_edge = 0;
            thickness = lib.mkDefault 32;
            font_family = config.stylix.fonts.monospace.name;
            font_weight = 600;
            background_opacity = config.stylix.opacity.desktop;
            radius = 0;
            capsule_radius = 4;
            shadow = false;
            widget_spacing = 8;
            start = [
              "taskbar"
              "media"
            ];
            center = [ ];
            end = [
              "group:tray"
              "group:connectivity"
              "group:system"
              "group:time"
            ];
            capsule_group =
              lib.mapAttrsToList
                (id: members: {
                  inherit id members;
                  fill = "surface_container";
                  radius = 4;
                  padding = 8;
                  widget_spacing = 4;
                })
                {
                  tray = [ "tray" ];
                  connectivity = [
                    "tailnet"
                    "network"
                    "bluetooth"
                  ];
                  system = [
                    "volume"
                    "battery"
                    "notifications"
                  ];
                  time = [
                    "agenda"
                    "weather"
                    "clock"
                  ];
                };
          };
          widget = {
            clock.format = "{:%a %d %b %H:%M}";
            taskbar = {
              group_by_workspace = true;
              hide_empty_workspaces = true;
              group_single_icon_per_app = true;
              prefer_symbolic_icons = true;
              workspace_label_placement = "inside";
              focused_output_only = true;
            };
            media = {
              hide_when_no_media = true;
              max_length = 160;
            };
            weather.show_condition = false;
            network.show_label = false;
            tailnet = {
              type = "rylos/tailnet:bar";
              show_count = false;
            };
            agenda.type = "marcos/agenda:bar";
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
          plugins = {
            enabled = [
              "rylos/tailnet"
              "marcos/agenda"
            ];
            source = [
              {
                name = "local";
                kind = "path";
                location = "${./noctalia-plugins}";
                enabled = true;
              }
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
              timeout = 600;
              locked_timeout = 60;
              action = "screen_off";
            };
            suspend = {
              timeout = 900;
              action = lib.mkDefault "lock_and_suspend";
            };
            battery-screen-off = {
              timeout = 180;
              action = "command";
              command = "${onBattery} ${umbriel} msg dpms-off";
              resume_command = "${umbriel} msg dpms-on";
            };
            battery-suspend = {
              timeout = 300;
              action = "command";
              command = "${onBattery} ${lib.getExe config.programs.noctalia.package} msg session lock-and-suspend";
            };
          };
        };
      };
      systemd.user.services.noctalia.Unit.X-RestartIfChanged = false;
    };
}
