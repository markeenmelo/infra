{
  flake.modules.homeManager.base.programs.tmux = {
    enable = true;
    shortcut = "a";
    keyMode = "vi";
    customPaneNavigationAndResize = true;
    baseIndex = 1;
    escapeTime = 10;
    historyLimit = 50000;
    clock24 = true;
    mouse = true;
    terminal = "tmux-256color";
    extraConfig = ''
      set -g renumber-windows on
      set -g set-clipboard on
      bind v split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
    '';
  };
}
