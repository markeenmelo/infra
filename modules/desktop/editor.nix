{
  flake.modules.homeManager.desktop =
    { lib, pkgs, ... }:
    let
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
        mutableUserSettings = false;
        extensions = [
          "biome"
          "neocmake"
          "nix"
        ];
        extraPackages = [
          pkgs.bash-language-server
          pkgs.biome
          pkgs.clang-tools
          pkgs.cmake
          pkgs.neocmakelsp
          pkgs.nixd
          pkgs.nixfmt
          pkgs.shfmt
          pkgs.typescript-language-server
        ];
        userSettings = {
          auto_update = false;
          base_keymap = "Zed";
          cli_default_open_behavior = "existing_window";
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
              formatter.external = {
                command = lib.getExe pkgs.nixfmt;
                arguments = [ "-" ];
              };
              language_servers = [
                "nixd"
                "!nil"
              ];
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
            "typescript-language-server".binary = {
              path = lib.getExe pkgs.typescript-language-server;
              arguments = [ "--stdio" ];
            };
          };
          search.search_on_type = false;
          telemetry = {
            diagnostics = false;
            metrics = false;
          };
          vim_mode = false;
        };
      };
    };
}
