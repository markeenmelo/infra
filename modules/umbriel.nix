{
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
                (_: {
                  curve = "easeout";
                  duration_ms = 150;
                });
          }
          {
            animation = {
              curve = "easeout";
              duration_ms = 150;
              overview.workspace_curve = "easeout";
              windows_in.style = "fade";
              windows_out.style = "fade";
            };
            appearance = {
              corner_radius = 6;
              shadow.enabled = false;
            };
            colors.border = {
              focused = color "base0D";
              unfocused = color "base02";
            };
            layout.struts = lib.genAttrs [ "top" "bottom" "left" "right" ] (_: -2);
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
