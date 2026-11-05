{
  flake.modules.homeManager.base =
    { pkgs, ... }:
    {
      programs.tmux = {
        enable = true;
        shortcut = "a";
        keyMode = "vi";
        customPaneNavigationAndResize = true;
        baseIndex = 1;
        escapeTime = 10;
        historyLimit = 50000;
        clock24 = true;
        mouse = true;
        plugins = [
          pkgs.tmuxPlugins.resurrect
          {
            plugin = pkgs.tmuxPlugins.continuum;
            extraConfig = "set -g @continuum-restore 'on'";
          }
        ];
        terminal = "tmux-256color";
        extraConfig = ''
          set -g renumber-windows on
          set -g set-clipboard on
          bind v split-window -h -c "#{pane_current_path}"
          bind - split-window -v -c "#{pane_current_path}"
        '';
      };
    };
}
