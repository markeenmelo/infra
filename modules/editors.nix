{ lib, ... }:
{
  # Console editor policy for composing hosts: one declaratively configured Neovim
  # replaces the NixOS nano default. The wrapper loads this configuration from
  # the Nix store, so a per-user ~/.config/nvim is deliberately ignored;
  # ThinkPad's graphical editing stays with its separately composed Zed concern.
  flake.modules.nixos.editors = {
    programs.neovim = {
      enable = true;
      # nano is no longer shipped, so EDITOR consumers (sudoedit, git,
      # nixos-rebuild edit) resolve to nvim at priority 900: a deliberate
      # session or host assignment can still override it.
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
