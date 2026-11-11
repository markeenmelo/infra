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
    in
    {
      stylix.targets.zed.colors.enable = false;
      programs.zed-editor = {
        enable = true;
        package = lib.mkDefault null;
        mutableUserSettings = false;
        extensions = [ "nix" ];
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
          disable_ai = true;
          telemetry = {
            diagnostics = false;
            metrics = false;
          };
          format_on_save = "on";
          lsp.nixd = {
            binary.path = lib.getExe pkgs.nixd;
            settings.formatting.command = [ (lib.getExe pkgs.nixfmt) ];
          };
          lsp.package-version-server.binary.path = lib.getExe pkgs.package-version-server;
          languages.Nix.language_servers = [
            "nixd"
            "!nil"
          ];
        };
      };
    };
}
