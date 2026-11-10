{
  flake.modules.homeManager.base =
    { config, lib, ... }:
    {
      programs.ghostty = {
        enable = true;
        package = lib.mkDefault null;
        settings = {
          keybind = "global:cmd+grave_accent=toggle_quick_terminal";
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
