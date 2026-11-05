{
  flake.modules.darwin.desktop.home-manager.users.marcos =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.vicinae ];
      launchd.agents.vicinae = {
        enable = true;
        config = {
          ProgramArguments = [ "${pkgs.vicinae}/Applications/Vicinae.app/Contents/MacOS/Vicinae" ];
          EnvironmentVariables.VICINAE_OVERRIDES = "${(pkgs.formats.json { }).generate "vicinae.json" {
            global_shortcuts.toggle = "control+space";
          }}";
          RunAtLoad = true;
          KeepAlive.SuccessfulExit = false;
        };
      };
    };
}
