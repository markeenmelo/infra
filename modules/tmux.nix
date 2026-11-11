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
        focusEvents = true;
        historyLimit = 50000;
        clock24 = true;
        mouse = true;
        disableConfirmationPrompt = true;
        plugins = [
          pkgs.tmuxPlugins.resurrect
          {
            plugin = pkgs.tmuxPlugins.continuum;
            extraConfig = ''
              set -g @continuum-restore 'on'
              set -g status-right ""
            '';
          }
        ];
        terminal = "tmux-256color";
        extraConfig = ''
          set -g renumber-windows on
          set -g set-clipboard on
          set -g status-left ""
          set -g status-style "bg=#${colors.base00},fg=#${colors.base03}"
          set -g window-status-current-style "fg=#${colors.base05},bold"
          set -g pane-border-style "fg=#${colors.base03}"
          set -g pane-active-border-style "fg=#${colors.base0D}"
          bind v split-window -h -c "#{pane_current_path}"
          bind - split-window -v -c "#{pane_current_path}"
          bind c new-window -c "#{pane_current_path}"
        '';
      };
    };
}
