{
  flake.modules.homeManager.base =
    { config, pkgs, ... }:
    let
      inherit (config.lib.stylix) colors;
    in
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
        disableConfirmationPrompt = true;
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
          set -g status off
          set -g pane-border-style "fg=#${colors.base03}"
          set -g pane-active-border-style "fg=#${colors.base0D}"
          bind v split-window -h -c "#{pane_current_path}"
          bind - split-window -v -c "#{pane_current_path}"
          bind c new-window -c "#{pane_current_path}"
          bind Left select-pane -L
          bind Down select-pane -D
          bind Up select-pane -U
          bind Right select-pane -R
        '';
      };
    };
}
