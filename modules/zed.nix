{
  flake.modules.homeManager.base =
    { lib, pkgs, ... }:
    let
      server = package: args: {
        binary = {
          path = lib.getExe package;
          arguments = args;
        };
      };
    in
    {
      programs.zed-editor = {
        enable = true;
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
        userKeymaps = [
          {
            context = "AgentPanel";
            bindings.secondary-n = "agent::NewTerminalThread";
          }
        ];
        userSettings = {
          icon_theme = {
            mode = "dark";
            dark = "Material Icon Theme";
            light = "Material Icon Theme";
          };
          agent = {
            dock = "right";
            sidebar_side = "right";
            threads_sidebar.auto_open = false;
            commit_message_model = {
              provider = "openai_subscribed";
              model = "gpt-5.4-nano";
            };
          };
          edit_predictions.provider = "none";
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
          project_panel.dock = "left";
          git_panel.dock = "left";
          outline_panel.dock = "left";
          terminal.dock = "bottom";
          title_bar.show_sign_in = false;
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
