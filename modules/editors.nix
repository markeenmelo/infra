{
  flake.modules.nixos.base = {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      configure.customLuaRC = ''
        vim.opt.mouse = "a"
        vim.opt.ignorecase = true
        vim.opt.smartcase = true
        vim.opt.expandtab = true
        vim.opt.tabstop = 4
        vim.opt.shiftwidth = 4
        vim.opt.undofile = true
      '';
    };
    programs.nano.enable = false;
  };
}
