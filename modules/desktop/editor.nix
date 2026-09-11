{
  # Zed, its language servers and the shared OLED Graphite theme. Settings are
  # the reviewed current preferences; only the Nix formatter changed, so the
  # editor and this repository's canonical `just fmt` cannot disagree.
  flake.modules.homeManager.hyprland =
    { lib, pkgs, ... }:
    let
      theme = lib.importJSON ./assets/oled-graphite.json;
      inherit (theme) colors;
      withAlpha = color: alpha: "${color}${alpha}";

      zedTheme = {
        "$schema" = "https://zed.dev/schema/themes/v0.2.0.json";
        inherit (theme) name;
        author = "Marcos Melo";
        themes = [
          {
            inherit (theme) name;
            appearance = "dark";
            style = {
              border = withAlpha colors.outline "ff";
              "border.variant" = withAlpha colors.raised "ff";
              "border.focused" = withAlpha colors.accent "ff";
              "border.selected" = withAlpha colors.accent "66";
              "border.transparent" = "#00000000";
              "border.disabled" = withAlpha colors.outline "80";
              "elevated_surface.background" = withAlpha colors.raised "ff";
              "surface.background" = withAlpha colors.surface "ff";
              background = withAlpha colors.background "ff";
              "element.background" = withAlpha colors.surface "ff";
              "element.hover" = withAlpha colors.raised "ff";
              "element.active" = withAlpha colors.elevated "ff";
              "element.selected" = withAlpha colors.elevated "ff";
              "element.disabled" = withAlpha colors.surface "ff";
              "drop_target.background" = withAlpha colors.accent "33";
              "ghost_element.background" = "#00000000";
              "ghost_element.hover" = withAlpha colors.raised "ff";
              "ghost_element.active" = withAlpha colors.elevated "ff";
              "ghost_element.selected" = withAlpha colors.elevated "ff";
              "ghost_element.disabled" = withAlpha colors.surface "ff";
              text = withAlpha colors.text "ff";
              "text.muted" = withAlpha colors.muted "ff";
              "text.placeholder" = withAlpha colors.muted "b3";
              "text.disabled" = withAlpha colors.muted "80";
              "text.accent" = withAlpha colors.accent "ff";
              icon = withAlpha colors.text "ff";
              "icon.muted" = withAlpha colors.muted "ff";
              "icon.disabled" = withAlpha colors.muted "80";
              "icon.placeholder" = withAlpha colors.muted "b3";
              "icon.accent" = withAlpha colors.accent "ff";
              "status_bar.background" = withAlpha colors.surface "ff";
              "title_bar.background" = withAlpha colors.surface "ff";
              "title_bar.inactive_background" = withAlpha colors.background "ff";
              "toolbar.background" = withAlpha colors.background "ff";
              "tab_bar.background" = withAlpha colors.surface "ff";
              "tab.inactive_background" = withAlpha colors.surface "ff";
              "tab.active_background" = withAlpha colors.background "ff";
              "search.match_background" = withAlpha colors.accent "40";
              "search.active_match_background" = withAlpha colors.attention "55";
              "panel.background" = withAlpha colors.surface "ff";
              "panel.focused_border" = withAlpha colors.accent "ff";
              "pane.focused_border" = withAlpha colors.accent "ff";
              "scrollbar.thumb.background" = withAlpha colors.muted "4d";
              "scrollbar.thumb.hover_background" = withAlpha colors.muted "80";
              "scrollbar.thumb.border" = withAlpha colors.outline "ff";
              "scrollbar.track.background" = "#00000000";
              "scrollbar.track.border" = withAlpha colors.raised "ff";
              "editor.foreground" = withAlpha colors.text "ff";
              "editor.background" = withAlpha colors.background "ff";
              "editor.gutter.background" = withAlpha colors.background "ff";
              "editor.subheader.background" = withAlpha colors.surface "ff";
              "editor.active_line.background" = withAlpha colors.surface "cc";
              "editor.highlighted_line.background" = withAlpha colors.raised "ff";
              "editor.line_number" = withAlpha colors.muted "99";
              "editor.active_line_number" = withAlpha colors.accent "ff";
              "editor.hover_line_number" = withAlpha colors.text "ff";
              "editor.invisible" = withAlpha colors.outline "ff";
              "editor.wrap_guide" = withAlpha colors.outline "66";
              "editor.active_wrap_guide" = withAlpha colors.muted "80";
              "editor.document_highlight.read_background" = withAlpha colors.accent "1f";
              "editor.document_highlight.write_background" = withAlpha colors.attention "26";
              "terminal.background" = withAlpha colors.background "ff";
              "terminal.foreground" = withAlpha colors.text "ff";
              "terminal.bright_foreground" = withAlpha colors.white "ff";
              "terminal.dim_foreground" = withAlpha colors.muted "ff";
              "terminal.ansi.black" = withAlpha colors.background "ff";
              "terminal.ansi.bright_black" = withAlpha colors.outline "ff";
              "terminal.ansi.dim_black" = withAlpha colors.surface "ff";
              "terminal.ansi.red" = withAlpha colors.red "ff";
              "terminal.ansi.bright_red" = withAlpha colors.brightRed "ff";
              "terminal.ansi.dim_red" = withAlpha colors.red "99";
              "terminal.ansi.green" = withAlpha colors.green "ff";
              "terminal.ansi.bright_green" = withAlpha colors.brightGreen "ff";
              "terminal.ansi.dim_green" = withAlpha colors.green "99";
              "terminal.ansi.yellow" = withAlpha colors.attention "ff";
              "terminal.ansi.bright_yellow" = withAlpha colors.brightYellow "ff";
              "terminal.ansi.dim_yellow" = withAlpha colors.attention "99";
              "terminal.ansi.blue" = withAlpha colors.blue "ff";
              "terminal.ansi.bright_blue" = withAlpha colors.brightBlue "ff";
              "terminal.ansi.dim_blue" = withAlpha colors.blue "99";
              "terminal.ansi.magenta" = withAlpha colors.magenta "ff";
              "terminal.ansi.bright_magenta" = withAlpha colors.brightMagenta "ff";
              "terminal.ansi.dim_magenta" = withAlpha colors.magenta "99";
              "terminal.ansi.cyan" = withAlpha colors.accent "ff";
              "terminal.ansi.bright_cyan" = withAlpha colors.accentBright "ff";
              "terminal.ansi.dim_cyan" = withAlpha colors.accent "99";
              "terminal.ansi.white" = withAlpha colors.text "ff";
              "terminal.ansi.bright_white" = withAlpha colors.white "ff";
              "terminal.ansi.dim_white" = withAlpha colors.muted "ff";
              "link_text.hover" = withAlpha colors.accentBright "ff";
              "version_control.added" = withAlpha colors.green "ff";
              "version_control.modified" = withAlpha colors.attention "ff";
              "version_control.word_added" = withAlpha colors.green "33";
              "version_control.word_deleted" = withAlpha colors.red "33";
              "version_control.deleted" = withAlpha colors.red "ff";
              conflict = withAlpha colors.attention "ff";
              "conflict.background" = withAlpha colors.attention "1a";
              "conflict.border" = withAlpha colors.attention "80";
              created = withAlpha colors.green "ff";
              "created.background" = withAlpha colors.green "1a";
              "created.border" = withAlpha colors.green "80";
              deleted = withAlpha colors.red "ff";
              "deleted.background" = withAlpha colors.red "1a";
              "deleted.border" = withAlpha colors.red "80";
              error = withAlpha colors.red "ff";
              "error.background" = withAlpha colors.red "1a";
              "error.border" = withAlpha colors.red "80";
              hidden = withAlpha colors.muted "ff";
              "hidden.background" = withAlpha colors.muted "1a";
              "hidden.border" = withAlpha colors.outline "ff";
              hint = withAlpha colors.blue "ff";
              "hint.background" = withAlpha colors.blue "1a";
              "hint.border" = withAlpha colors.blue "80";
              ignored = withAlpha colors.muted "ff";
              "ignored.background" = withAlpha colors.muted "1a";
              "ignored.border" = withAlpha colors.outline "ff";
              info = withAlpha colors.accent "ff";
              "info.background" = withAlpha colors.accent "1a";
              "info.border" = withAlpha colors.accent "80";
              modified = withAlpha colors.attention "ff";
              "modified.background" = withAlpha colors.attention "1a";
              "modified.border" = withAlpha colors.attention "80";
              predictive = withAlpha colors.muted "cc";
              "predictive.background" = withAlpha colors.muted "1a";
              "predictive.border" = withAlpha colors.outline "ff";
              renamed = withAlpha colors.accent "ff";
              "renamed.background" = withAlpha colors.accent "1a";
              "renamed.border" = withAlpha colors.accent "80";
              success = withAlpha colors.green "ff";
              "success.background" = withAlpha colors.green "1a";
              "success.border" = withAlpha colors.green "80";
              unreachable = withAlpha colors.muted "ff";
              "unreachable.background" = withAlpha colors.muted "1a";
              "unreachable.border" = withAlpha colors.outline "ff";
              warning = withAlpha colors.attention "ff";
              "warning.background" = withAlpha colors.attention "1a";
              "warning.border" = withAlpha colors.attention "80";
              players =
                map
                  (color: {
                    cursor = withAlpha color "ff";
                    background = withAlpha color "ff";
                    selection = withAlpha color "3d";
                  })
                  [
                    colors.accent
                    colors.red
                    colors.attention
                    colors.magenta
                    colors.blue
                    colors.accentBright
                    colors.green
                    colors.text
                  ];
              syntax = {
                attribute.color = colors.accent;
                boolean.color = colors.attention;
                comment = {
                  color = colors.muted;
                  font_style = "italic";
                };
                "comment.doc" = {
                  color = withAlpha colors.muted "cc";
                  font_style = "italic";
                };
                constant.color = colors.attention;
                constructor.color = colors.accent;
                embedded.color = colors.text;
                emphasis = {
                  color = colors.accent;
                  font_style = "italic";
                };
                "emphasis.strong" = {
                  color = colors.attention;
                  font_weight = 700;
                };
                enum.color = colors.accentBright;
                function.color = colors.blue;
                hint.color = colors.muted;
                keyword.color = colors.magenta;
                label.color = colors.accent;
                link_text = {
                  color = colors.blue;
                  font_style = "italic";
                };
                link_uri.color = colors.accent;
                namespace.color = colors.accentBright;
                number.color = colors.attention;
                operator.color = colors.accent;
                predictive = {
                  color = colors.muted;
                  font_style = "italic";
                };
                preproc.color = colors.magenta;
                primary.color = colors.text;
                property.color = colors.red;
                punctuation.color = colors.text;
                "punctuation.bracket".color = colors.muted;
                "punctuation.delimiter".color = colors.muted;
                "punctuation.list_marker".color = colors.red;
                "punctuation.markup".color = colors.red;
                "punctuation.special".color = colors.attention;
                selector.color = colors.attention;
                "selector.pseudo".color = colors.accent;
                string.color = colors.green;
                "string.escape".color = colors.accentBright;
                "string.regex".color = colors.attention;
                "string.special".color = colors.attention;
                "string.special.symbol".color = colors.attention;
                tag.color = colors.accent;
                text.literal.color = colors.green;
                title = {
                  color = colors.red;
                  font_weight = 500;
                };
                type.color = colors.accentBright;
                variable.color = colors.text;
                "variable.parameter".color = colors.red;
                "variable.special".color = colors.magenta;
                variant.color = colors.blue;
                "diff.plus".color = colors.green;
                "diff.minus".color = colors.red;
              };
            };
          }
        ];
      };

      clangLanguageSettings = {
        format_on_save = "on";
        formatter.language_server.name = "clangd";
        inlay_hints.enabled = true;
        language_servers = [ "clangd" ];
      };
      biomeLanguageSettings = {
        format_on_save = "on";
        formatter.language_server.name = "biome";
        inlay_hints.enabled = true;
        language_servers = [
          "typescript-language-server"
          "biome"
        ];
        tab_size = 2;
      };
    in
    {
      programs.zed-editor = {
        enable = true;
        # Zed's own settings UI cannot write back into the Nix store copy; every
        # change belongs in this module so the editor stays reproducible.
        mutableUserSettings = false;
        themes.oled-graphite = zedTheme;
        extensions = [
          "biome"
          "neocmake"
          "nix"
          "opentofu"
        ];
        extraPackages = [
          pkgs.bash-language-server
          pkgs.biome
          pkgs.clang-tools
          pkgs.cmake
          pkgs.neocmakelsp
          pkgs.nixd
          pkgs.nixfmt
          pkgs.opentofu
          pkgs.shfmt
          pkgs.tofu-ls
          pkgs.typescript-language-server
        ];
        userSettings = {
          # Nixpkgs owns this build; an in-app update would fight the store copy.
          auto_update = false;
          base_keymap = "Zed";
          buffer_font_family = "JetBrainsMono Nerd Font";
          buffer_font_size = 15;
          cli_default_open_behavior = "existing_window";
          file_types = {
            OpenTofu = [
              "tf"
              "tofu"
            ];
            "OpenTofu Vars" = [ "tfvars" ];
          };
          languages = {
            C = clangLanguageSettings;
            "C++" = clangLanguageSettings;
            CMake = {
              format_on_save = "on";
              formatter.language_server.name = "cmake";
              language_servers = [ "cmake" ];
              tab_size = 2;
            };
            JavaScript = biomeLanguageSettings;
            Nix = {
              format_on_save = "on";
              # The repository formats with official nixfmt through nixfmt-tree,
              # so the editor must not reformat files with a different style.
              # "-" is the supported anonymous-stdin form; a bare invocation
              # still works but is deprecated and warns on stderr.
              formatter.external = {
                command = lib.getExe pkgs.nixfmt;
                arguments = [ "-" ];
              };
              language_servers = [
                "nixd"
                "!nil"
              ];
            };
            OpenTofu = {
              format_on_save = "on";
              formatter = "language_server";
            };
            "OpenTofu Vars" = {
              format_on_save = "on";
              formatter = "language_server";
            };
            "Shell Script" = {
              format_on_save = "on";
              formatter = "language_server";
              tab_size = 2;
            };
            TSX = biomeLanguageSettings;
            TypeScript = biomeLanguageSettings;
          };
          lsp = {
            biome = {
              binary = {
                path = lib.getExe pkgs.biome;
                arguments = [ "lsp-proxy" ];
              };
              settings.require_config_file = false;
            };
            clangd.binary.path = lib.getExe' pkgs.clang-tools "clangd";
            nixd.binary.path = lib.getExe pkgs.nixd;
            tofu-ls.settings.tofu.path = lib.getExe pkgs.opentofu;
            "typescript-language-server".binary = {
              path = lib.getExe pkgs.typescript-language-server;
              arguments = [ "--stdio" ];
            };
          };
          # Zed 1.19 enabled project search while typing by default. Preserve
          # the previously reviewed explicit-submit behavior across the update.
          search.search_on_type = false;
          telemetry = {
            diagnostics = false;
            metrics = false;
          };
          terminal = {
            font_family = "JetBrainsMono Nerd Font";
            font_size = 14;
          };
          theme = theme.name;
          ui_font_family = "JetBrainsMono Nerd Font";
          ui_font_size = 16;
          vim_mode = false;
        };
      };
    };
}
