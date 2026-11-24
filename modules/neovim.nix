{
  flake.modules.homeManager.base =
    { config, pkgs, ... }:
    let
      c = config.lib.stylix.colors.withHashtag;
    in
    {
      stylix.targets.neovim.enable = false;
      programs.neovim = {
        enable = true;
        defaultEditor = true;
        viAlias = true;
        vimAlias = true;
        plugins = [
          {
            plugin = pkgs.vimPlugins.tokyonight-nvim;
            type = "lua";
            config = ''
              require('tokyonight').setup({
                style = 'night',
                on_colors = function(colors)
                  colors.bg = '${c.base00}'
                  colors.bg_dark = '${c.base00}'
                  colors.bg_float = '${c.base01}'
                  colors.bg_sidebar = '${c.base00}'
                  colors.bg_statusline = '${c.base01}'
                  colors.bg_highlight = '${c.base01}'
                end,
              })
              vim.cmd.colorscheme('tokyonight')
            '';
          }
        ];
      };
    };
}
