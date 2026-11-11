{
  flake.modules.homeManager.base =
    { lib, pkgs, ... }:
    {
      programs.zed-editor = {
        enable = true;
        package = lib.mkDefault null;
        mutableUserSettings = false;
        extensions = [ "nix" ];
        userSettings = {
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
