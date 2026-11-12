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
            plugin = pkgs.vimPlugins.onedark-nvim;
            type = "lua";
            config = ''
              require('onedark').setup({
                style = 'dark',
                colors = {
                  bg0 = '${c.base00}',
                  bg1 = '${c.base01}',
                  bg2 = '${c.base02}',
                  bg3 = '${c.base02}',
                  bg_d = '${c.base00}',
                },
              })
              require('onedark').load()
            '';
          }
        ];
      };
    };
}
