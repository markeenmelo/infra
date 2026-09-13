{ lib, ... }:
{
  flake.modules.nixos.editors = {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      configure.customLuaRC = ''
        -- Fleet console editor baseline: terminal-first and stateless,
        -- identical for root and users on every host. No plugins or language
        -- provider runtimes are wrapped into the system closures.
        vim.opt.number = true
        vim.opt.relativenumber = true
        vim.opt.mouse = "a"
        -- Case-insensitive search unless the pattern contains a capital letter.
        vim.opt.ignorecase = true
        vim.opt.smartcase = true
        -- Four-space soft tabs; repository layout stays owned by treefmt.
        vim.opt.expandtab = true
        vim.opt.tabstop = 4
        vim.opt.shiftwidth = 4
        vim.opt.scrolloff = 8
        vim.opt.signcolumn = "yes"
        vim.opt.splitbelow = true
        vim.opt.splitright = true
        -- Undo history lives under the user's XDG state directory, never next
        -- to the edited file; on tmpfs-root hosts it stays deliberately
        -- ephemeral instead of adding a persistence entry.
        vim.opt.undofile = true
      '';
    };
    programs.nano.enable = false;
  };

  fleet.validation.hostChecks.editors =
    {
      name,
      host,
      system,
      ...
    }:
    let
      cfg = system.config;
    in
    assert lib.assertMsg (
      (lib.elem "editors" host.capabilities)
      -> (
        cfg.programs.neovim.enable
        && cfg.programs.neovim.defaultEditor
        && cfg.programs.neovim.viAlias
        && cfg.programs.neovim.vimAlias
        && cfg.environment.sessionVariables.EDITOR == "nvim"
        && !cfg.programs.nano.enable
      )
    ) "${name}: hosts composing editors must ship configured Neovim as the sole console editor";
    true;
}
