{
  # Terminal and multiplexer preferences for the ThinkPad desktop.
  # These are the reviewed current application preferences, re-expressed through
  # native Home Manager program modules instead of hand-written dotfiles.
  flake.modules.homeManager.desktop =
    {
      lib,
      pkgs,
      ...
    }:
    let
      theme = lib.importJSON ./assets/oled-graphite.json;
      inherit (theme) colors;
    in
    {
      xdg.terminal-exec = {
        enable = true;
        settings.default = [ "com.mitchellh.ghostty.desktop" ];
      };
      home.packages = [ pkgs.nerd-fonts.jetbrains-mono ];
      # One patched family for Ghostty, Zed and prompt icons; no regular variant.
      # Keep native sans/serif/emoji defaults, including Noto Color Emoji: Nerd
      # Font symbols are not a replacement for a color-emoji font.
      fonts.fontconfig.defaultFonts.monospace = [ "JetBrainsMono Nerd Font" ];

      programs = {
        ghostty = {
          enable = true;
          settings = {
            # Herdr owns panes/sessions inside the terminal, as it does today.
            command = "direct:${lib.getExe pkgs.herdr}";
            theme = theme.name;
            font-family = "JetBrainsMono Nerd Font";
            font-size = 13;
            background-opacity = 1.0;
            bold-is-bright = false;
            cursor-style = "bar";
            cursor-style-blink = false;
            mouse-hide-while-typing = true;
            unfocused-split-opacity = 0.9;
            unfocused-split-fill = colors.background;
            split-divider-color = colors.outline;
            window-decoration = "none";
            window-padding-x = 14;
            window-padding-y = 10;
            window-padding-balance = true;
            window-padding-color = "background";
          };
          themes.${theme.name} = {
            inherit (colors) background;
            foreground = colors.text;
            cursor-color = colors.accent;
            cursor-text = colors.background;
            selection-background = colors.outline;
            selection-foreground = colors.text;
            palette = [
              "0=${colors.background}"
              "1=${colors.red}"
              "2=${colors.green}"
              "3=${colors.attention}"
              "4=${colors.blue}"
              "5=${colors.magenta}"
              "6=${colors.accent}"
              "7=${colors.text}"
              "8=${colors.outline}"
              "9=${colors.brightRed}"
              "10=${colors.brightGreen}"
              "11=${colors.brightYellow}"
              "12=${colors.brightBlue}"
              "13=${colors.brightMagenta}"
              "14=${colors.accentBright}"
              "15=${colors.white}"
            ];
          };
        };

        herdr = {
          enable = true;
          settings = {
            keys.prefix = "ctrl+a";
            onboarding = false;
            terminal.default_shell = lib.getExe pkgs.zsh;
            update = {
              # Herdr may check its own integration manifests, but this build is
              # pinned by Nixpkgs: never advertise or fetch a newer release.
              manifest_check = true;
              version_check = false;
            };
            ui = {
              agent_panel_sort = "priority";
              show_agent_labels_on_pane_borders = true;
              sidebar_start_collapsed = true;
              sidebar_width = 32;
              status_indicators = "symbols";
              toast.delivery = "herdr";
            };
            session.resume_agents_on_restore = true;
            experimental.pane_history = false;
          };
        };
      };
    };
}
