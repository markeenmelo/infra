{ config, lib, ... }:
{
  flake.checks =
    import ./_host-checks.nix { inherit config lib; } "desktop-config"
      (nixos: nixos.config.programs.umbriel.enable)
      (
        host: nixos:
        let
          home = nixos.config.home-manager.users.marcos;
        in
        nixos.pkgs.runCommand "desktop-config-${host}" { } ''
          ${lib.getExe nixos.config.programs.umbriel.package} config validate -c ${
            home.xdg.configFile."umbriel/config.toml".source
          }
          ${lib.getExe home.programs.noctalia.package} config validate ${
            home.xdg.configFile."noctalia/config.toml".source
          } 2>&1 | tee log
          [ -z "$(grep WARN log)" ]
          touch $out
        ''
      );

  flake.modules.nixos.desktop = {
    programs.umbriel.enable = true;
    environment.sessionVariables.NIXOS_OZONE_WL = "1";
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
      toml = pkgs.formats.toml { };
      spawn = package: "spawn ${lib.getExe package}";
      noctalia = args: "${spawn config.programs.noctalia.package} msg ${args}";
      panel = action: "${lib.getExe osConfig.programs.umbriel.package} msg output-${action} eDP-1";
      color = name: "#${config.lib.stylix.colors.${name}}ff";
    in
    {
      options.programs.umbriel.settings = lib.mkOption {
        inherit (toml) type;
        description = "Umbriel configuration layered over its packaged config.toml; tables merge by key and the last file wins.";
      };
      config = {
        programs.umbriel.settings = lib.mkMerge [
          {
            animation =
              lib.genAttrs
                [
                  "border"
                  "dialogs"
                  "dim_unfocused"
                  "layers"
                  "overview"
                  "scratchpad"
                  "windows_in"
                  "windows_move"
                  "windows_opacity"
                  "windows_out"
                  "windows_resize"
                  "workspaces"
                ]
                (event: {
                  curve = "easeout";
                  duration_ms = if event == "windows_out" then 120 else 300;
                });
          }
          {
            animation = {
              curve = "easeout";
              duration_ms = 300;
              overview.workspace_curve = "easeout";
              windows_in = {
                style = "popin";
                scale = 0.87;
              };
              windows_out = {
                style = "popin";
                scale = 0.87;
              };
              workspaces.enabled = false;
            };
            general.show_cheatsheet = false;
            appearance = {
              corner_radius = 0;
              shadow.enabled = false;
            };
            colors.border = {
              focused = color "base0D";
              unfocused = color "base02";
            };
            input = {
              keyboard = {
                repeat_rate = 40;
                repeat_delay = 300;
              };
              touchpad.click_method = "clickfinger";
            };
            layout = {
              extent_presets = [
                0.25
                0.333
                0.5
                0.667
              ];
              gap = 10;
            };
            window_rule = [ { blur = false; } ];
          }
          {
            include.files = [ "${osConfig.programs.umbriel.package}/share/umbriel/config.toml" ];
            events = {
              lid_close = panel "disable";
              lid_open = panel "enable";
            };
            keybinds = {
              "Mod+Return" = {
                action = spawn config.programs.ghostty.package;
                repeat = false;
              };
              "Mod+B" = spawn config.programs.zen-browser.package;
              "Mod+E" = spawn pkgs.nautilus;
              "Mod+Escape" = noctalia "panel-toggle session";
              "Mod+Slash" = "cheatsheet-toggle";
              "Mod+Space" = noctalia "panel-toggle launcher";
              # shortcut: Umbriel cannot unbind a stock key, so the stock bare-Mod launcher and scratchpad binds do nothing through cheatsheet-close; drop when it can
              "Mod" = "cheatsheet-close";
              "Mod+Shift+Space" = "cheatsheet-close";
              "Mod+Ctrl+Space" = "cheatsheet-close";
              "Mod+Tab" = "cheatsheet-close";
              "Mod+Z" = spawn config.programs.zed-editor.package;
              "Alt+Tab" = noctalia "window-switcher hold";
              "Alt+Shift+Tab" = noctalia "window-switcher hold reverse";
              "Mod+Shift+A" = noctalia "screenshot-annotate";
              "Mod+Ctrl+A" = noctalia "annotate";
              "Mod+N" = noctalia "panel-toggle control-center";
              "Mod+Shift+L" = noctalia "session lock";
              "Print" = noctalia "screenshot-region";
              "Shift+Print" = noctalia "screenshot-fullscreen";
            };
          }
        ];
        xdg.configFile."umbriel/config.toml".source =
          toml.generate "umbriel.toml" config.programs.umbriel.settings;
      };
    };
}
