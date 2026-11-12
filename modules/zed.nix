{
  flake.modules.homeManager.base =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      c = config.lib.stylix.colors.withHashtag;
      server = package: args: {
        binary = {
          path = lib.getExe package;
          arguments = args;
        };
      };
    in
    {
      stylix.targets.zed.colors.enable = false;
      programs.zed-editor = {
        enable = true;
        package = lib.mkDefault null;
        mutableUserSettings = false;
        extensions = [
          "nix"
          "toml"
          "terraform"
          "lua"
          "marksman"
          "basher"
          "just"
          "material-icon-theme"
        ];
        userSettings = {
          theme = "One Dark";
          theme_overrides."One Dark" = {
            "editor.background" = c.base00;
            "editor.gutter.background" = c.base00;
            "terminal.background" = c.base00;
            "tab.active_background" = c.base00;
            "background" = c.base01;
            "title_bar.background" = c.base01;
            "status_bar.background" = c.base01;
            "panel.background" = c.base01;
            "tab_bar.background" = c.base01;
            "tab.inactive_background" = c.base01;
            "toolbar.background" = c.base00;
            "surface.background" = c.base01;
            "elevated_surface.background" = c.base01;
            "editor.active_line.background" = c.base01;
            "border" = c.base02;
          };
          icon_theme = {
            mode = "dark";
            dark = "Material Icon Theme";
            light = "Material Icon Theme";
          };
          edit_predictions.provider = "copilot";
          agent.commit_message_model = {
            provider = "copilot_chat";
            model = "gpt-4.1";
          };
          agent_servers.claude-acp.type = "registry";
          telemetry = {
            diagnostics = false;
            metrics = false;
          };
          format_on_save = "on";
          autosave = "on_focus_change";
          load_direnv = "shell_hook";
          cursor_blink = false;
          current_line_highlight = "gutter";
          minimap.show = "never";
          tab_bar.show_nav_history_buttons = false;
          collaboration_panel.button = false;
          node = {
            path = lib.getExe pkgs.nodejs;
            npm_path = lib.getExe' pkgs.nodejs "npm";
          };
          lsp = {
            nixd = {
              binary.path = lib.getExe pkgs.nixd;
              settings.formatting.command = [ (lib.getExe pkgs.nixfmt) ];
            };
            package-version-server.binary.path = lib.getExe pkgs.package-version-server;
            clangd.binary.path = lib.getExe' pkgs.clang-tools "clangd";
            ruff = server pkgs.ruff [ "server" ];
            taplo = server pkgs.taplo [
              "lsp"
              "stdio"
            ];
            terraform-ls = server pkgs.terraform-ls [ "serve" ];
            lua-language-server = server pkgs.lua-language-server [ ];
            marksman = server pkgs.marksman [ "server" ];
            just-lsp = server pkgs.just-lsp [ ];
          };
          languages.Nix.language_servers = [
            "nixd"
            "!nil"
          ];
        };
      };
    };
}
