{
  flake.modules.homeManager.base =
    { config, lib, ... }:
    let
      inherit (config.lib.stylix.colors) withHashtag;
    in
    {
      programs.zellij = {
        enable = true;
        enableZshIntegration = false;
        settings = {
          default_layout = "compact";
          pane_frames = false;
          scroll_buffer_size = 50000;
          copy_on_select = true;
          show_startup_tips = false;
          show_release_notes = false;
        };
        themes.stylix.themes.default = {
          ribbon_selected.background = lib.mkForce withHashtag.base0D;
          frame_selected.base = lib.mkForce withHashtag.base0D;
        };
        extraConfig = ''
          keybinds {
            unbind "Ctrl b" "Ctrl g" "Ctrl h" "Ctrl n" "Ctrl o" "Ctrl p" "Ctrl q" "Ctrl s" "Ctrl t"
            unbind "Alt f" "Alt n" "Alt i" "Alt o" "Alt h" "Alt j" "Alt k" "Alt l" "Alt p" "Alt Shift p"
            unbind "Alt Left" "Alt Right" "Alt Up" "Alt Down" "Alt =" "Alt +" "Alt -" "Alt [" "Alt ]"
            shared_except "tmux" "locked" {
              bind "Ctrl a" { SwitchToMode "Tmux"; }
            }
            tmux {
              bind "Ctrl a" { Write 1; SwitchToMode "Normal"; }
              bind "v" { NewPane "Right"; SwitchToMode "Normal"; }
              bind "-" { NewPane "Down"; SwitchToMode "Normal"; }
              bind "H" { Resize "Increase Left"; }
              bind "J" { Resize "Increase Down"; }
              bind "K" { Resize "Increase Up"; }
              bind "L" { Resize "Increase Right"; }
              bind "P" { SwitchToMode "Pane"; }
              bind "t" { SwitchToMode "Tab"; }
              bind "r" { SwitchToMode "Resize"; }
              bind "m" { SwitchToMode "Move"; }
              bind "s" { SwitchToMode "Session"; }
            }
          }
        '';
      };
    };
}
