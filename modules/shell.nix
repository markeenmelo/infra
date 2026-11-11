{
  flake.modules.darwin.base.programs.zsh = {
    enableGlobalCompInit = false;
    promptInit = "";
  };

  flake.modules.homeManager.base.stylix.targets.bat.enable = false;

  flake.modules.homeManager.base.programs = {
    zsh = {
      enable = true;
      autocd = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      defaultKeymap = "emacs";
      initContent = ''
        note() {
          mkdir -p ~/notes
          printf -- '- %s %s\n' "$(date '+%F %H:%M')" "$*" >> ~/notes/inbox.md
        }
      '';
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
    bat = {
      enable = true;
      config.theme = "OneHalfDark";
    };
    fd.enable = true;
    ripgrep.enable = true;
  };
}
