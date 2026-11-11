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
      exitNode = "${lib.getExe osConfig.services.tailscale.package} status --json | ${lib.getExe pkgs.jq} -r ${lib.escapeShellArg ''if .BackendState != "Running" then "off" else ([(.Peer // {})[] | select(.ExitNode) | .DNSName | split(".")[0]][0] // "direct") end''}";
      plugins = pkgs.linkFarm "noctalia-plugins" {
        "tailnet/plugin.toml" = pkgs.writeText "plugin.toml" ''
          id = "infra/tailnet"
          name = "Tailnet"
          version = "1.0.0"
          plugin_api = 43
          author = "infra"
          description = "Tailscale state and the exit node in use."

          [[widget]]
          id = "tailnet"
          entry = "widget.luau"
        '';
        "tailnet/widget.luau" = pkgs.writeText "widget.luau" ''
          --!nonstrict
          local state = "…"

          local function render()
            barWidget.render(ui.row({ gap = 4, align = "center" }, {
              ui.glyph({ name = "world" }),
              ui.label({ text = state, maxLines = 1 }),
            }))
          end

          function update()
            noctalia.runAsync(${lib.generators.toLua { } exitNode}, function(result)
              local text = string.gsub(result.stdout or "", "%s+$", "")
              if result.exitCode ~= 0 or text == "" then
                text = "?"
              end
              if text ~= state then
                state = text
                render()
              end
            end)
          end

          noctalia.setUpdateInterval(30000)
          render()
          update()
        '';
      };
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
              "cpu"
              "memory"
              "tailnet"
              "network"
              "bluetooth"
              "volume"
              "brightness"
              "battery"
              "notifications"
              "control-center"
              "session"
              "clock"
            ];
          };
          widget = {
            clock.format = "{:%a %d %b %H:%M}";
            cpu = {
              type = "sysmon";
              stat = "cpu_usage";
              visualization = "none";
            };
            memory = {
              type = "sysmon";
              stat = "ram_used";
              visualization = "none";
            };
            media.hide_when_no_media = true;
            tailnet.type = "infra/tailnet:tailnet";
          };
          plugins = {
            enabled = [ "infra/tailnet" ];
            source = [
              {
                name = "infra";
                kind = "path";
                location = "${plugins}";
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
