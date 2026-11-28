{
  flake.modules.homeManager.desktop.programs.ghostty.settings.window-decoration = "none";

  flake.modules.homeManager.base =
    { config, lib, ... }:
    {
      programs.ghostty = {
        enable = true;
        settings = {
          command = "${lib.getExe config.programs.zellij.package} attach --create main";
          confirm-close-surface = false;
          window-padding-x = 10;
          window-padding-y = 8;
          window-padding-balance = true;
          cursor-style = "block";
          mouse-hide-while-typing = true;
        };
      };
    };
}
