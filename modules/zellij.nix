{
  flake.modules.homeManager.base =
    { config, lib, ... }:
    let
      inherit (config.lib.stylix.colors) withHashtag;
    in
    {
      programs.zellij = {
        enable = true;
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
            unbind "Ctrl b"
            shared_except "tmux" "locked" {
              bind "Ctrl a" { SwitchToMode "Tmux"; }
            }
            tmux {
              bind "Ctrl a" { Write 1; SwitchToMode "Normal"; }
              bind "v" { NewPane "Right"; SwitchToMode "Normal"; }
              bind "-" { NewPane "Down"; SwitchToMode "Normal"; }
            }
          }
        '';
      };
    };
}
