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
            plugin = pkgs.vimPlugins.everforest;
            type = "lua";
            config = ''
              vim.g.everforest_background = 'medium'
              vim.g.everforest_colors_override = {
                bg0 = { '${c.base00}', '235' },
                bg1 = { '${c.base01}', '236' },
                bg3 = { '${c.base02}', '238' },
              }
              vim.cmd.colorscheme('everforest')
            '';
          }
        ];
      };
    };
}
