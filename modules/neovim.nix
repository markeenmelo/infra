{
  flake.modules.homeManager.base =
    { pkgs, ... }:
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
              require('onedark').setup({ style = 'dark' })
              require('onedark').load()
            '';
          }
        ];
      };
    };
}
