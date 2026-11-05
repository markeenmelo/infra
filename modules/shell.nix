{
  flake.modules.darwin.base.programs.zsh = {
    enableGlobalCompInit = false;
    promptInit = "";
  };

  flake.modules.homeManager.base.programs = {
    zsh = {
      enable = true;
      autocd = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      defaultKeymap = "emacs";
    };
    starship = {
      enable = true;
      settings = {
        add_newline = false;
        format = "$directory$git_branch$git_status$nix_shell$cmd_duration$line_break$character";
      };
    };
    direnv = {
      enable = true;
      silent = true;
      nix-direnv.enable = true;
    };
    fzf.enable = true;
    zoxide.enable = true;
    eza.enable = true;
    bat.enable = true;
    fd.enable = true;
    ripgrep.enable = true;
  };
}
