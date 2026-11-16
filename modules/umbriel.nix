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
    in
    {
      options.programs.umbriel.settings = lib.mkOption {
        inherit (toml) type;
        description = "Umbriel configuration layered over its packaged config.toml; tables merge by key and the last file wins.";
      };
      config = {
        programs.umbriel.settings = {
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
        };
        xdg.configFile."umbriel/config.toml".source =
          toml.generate "umbriel.toml" config.programs.umbriel.settings;
      };
    };
}
