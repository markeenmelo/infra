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
      shellAliases.cat = "bat -pp";
      history = {
        size = 50000;
        save = 50000;
        share = true;
        extended = true;
        ignoreDups = true;
        ignoreSpace = true;
        expireDuplicatesFirst = true;
      };
      initContent = ''
        note() {
          mkdir -p ~/notes
          printf -- '- %s %s\n' "$(date '+%F %H:%M')" "$*" >> ~/notes/inbox.md
        }

        sudo-command-line() {
          [[ -z $BUFFER ]] && zle up-history
          if [[ $BUFFER == sudo\ * ]]; then
            BUFFER=''${BUFFER#sudo }
            (( CURSOR = CURSOR > 5 ? CURSOR - 5 : 0 ))
          else
            BUFFER="sudo $BUFFER"
            (( CURSOR += 5 ))
          fi
        }
        autoload -Uz up-line-or-beginning-search down-line-or-beginning-search edit-command-line
        zle -N sudo-command-line
        zle -N up-line-or-beginning-search
        zle -N down-line-or-beginning-search
        zle -N edit-command-line

        WORDCHARS=''${WORDCHARS//\/}
        bindkey '^[^[' sudo-command-line
        bindkey '^[[1;5D' backward-word '^[[1;3D' backward-word
        bindkey '^[[1;5C' forward-word '^[[1;3C' forward-word
        bindkey '^[[H' beginning-of-line '^[OH' beginning-of-line
        bindkey '^[[F' end-of-line '^[OF' end-of-line
        bindkey '^[[3~' delete-char '^[[3;5~' kill-word '^H' backward-kill-word
        bindkey '^[[A' up-line-or-beginning-search '^[OA' up-line-or-beginning-search
        bindkey '^[[B' down-line-or-beginning-search '^[OB' down-line-or-beginning-search
        bindkey '^X^E' edit-command-line

        zstyle ':completion:*' menu select
        zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
        zstyle -e ':completion:*' list-colors 'reply=(''${(s.:.)LS_COLORS})'
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
    vivid.enable = true;
    zoxide.enable = true;
    eza = {
      enable = true;
      icons = "auto";
    };
    bat = {
      enable = true;
      config.theme = "OneHalfDark";
    };
    fd.enable = true;
    ripgrep.enable = true;
  };
}
