{
  # Terminal, multiplexer and shell comfort tools for the ThinkPad desktop.
  # These are the reviewed current application preferences, re-expressed through
  # native Home Manager program modules instead of hand-written dotfiles.
  flake.modules.homeManager.hyprland =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      theme = lib.importJSON ./assets/oled-graphite.json;
      inherit (theme) colors;
    in
    {
      home.packages = [
        pkgs.jetbrains-mono
        pkgs.nerd-fonts.jetbrains-mono
      ];
      # Ghostty and Zed both request this family by name; the Nerd Font variant
      # supplies the shell/prompt glyphs. Sans/serif/emoji policy is not decided
      # here, so only the monospace default is claimed by this concern.
      fonts.fontconfig.defaultFonts.monospace = [ "JetBrains Mono" ];

      programs = {
        ghostty = {
          enable = true;
          enableZshIntegration = true;
          settings = {
            # Herdr owns panes/sessions inside the terminal, as it does today.
            command = "direct:${lib.getExe pkgs.herdr}";
            theme = theme.name;
            font-family = [
              "JetBrains Mono"
              "JetBrainsMono Nerd Font"
            ];
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

        zsh = {
          enable = true;
          autosuggestion.enable = true;
          enableCompletion = true;
          syntaxHighlighting.enable = true;
          # Home Manager #9349: the stock zoxide hook is ordered before Starship
          # and clobbers its precmd chain, so zoxide is initialised last instead.
          initContent = lib.mkOrder 2000 ''
            eval "$(${lib.getExe config.programs.zoxide.package} init zsh)"
          '';
        };

        starship = {
          enable = true;
          enableZshIntegration = true;
        };

        fzf = {
          enable = true;
          enableBashIntegration = false;
          enableFishIntegration = false;
          enableNushellIntegration = false;
          enableZshIntegration = true;
        };

        zoxide = {
          enable = true;
          enableBashIntegration = false;
          enableFishIntegration = false;
          enableNushellIntegration = false;
          # Initialised explicitly above; see the ordering note.
          enableZshIntegration = false;
        };

        bat.enable = true;
        fd.enable = true;
        ripgrep.enable = true;
        eza = {
          enable = true;
          enableZshIntegration = true;
          icons = "auto";
          git = true;
        };

        git = {
          enable = true;
          settings.user = {
            name = "Marcos Melo";
            email = "marcosmelo@proton.me";
            # Refuse to guess an identity from the hostname/login for new repos.
            useConfigOnly = true;
          };
        };
      };
    };
}
