{
  flake.modules.homeManager.base =
    { config, lib, ... }:
    {
      programs.ghostty = {
        enable = true;
        package = null;
        settings = {
          command = "${lib.getExe config.programs.tmux.package} new-session -A -s main";
          confirm-close-surface = false;
          window-padding-x = 10;
          window-padding-y = 8;
          window-padding-balance = true;
          cursor-style = "bar";
          mouse-hide-while-typing = true;
        };
      };
    };
}
