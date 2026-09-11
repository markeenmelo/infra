{
  flake.modules.nixos.desktop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      programs.zsh.enable = true;
      users.users = lib.optionalAttrs (config.fleet.access.admin != null) {
        ${config.fleet.access.admin}.shell = pkgs.zsh;
      };
    };
  flake.modules.homeManager.desktop = { config, lib, ... }: {
    programs = {
      zsh = {
        enable = true;
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;
        # Home Manager #9349: the stock zoxide hook is ordered before Starship
        # and clobbers its precmd chain, so zoxide is initialised last instead.
        initContent = lib.mkOrder 2000 ''
          eval "$(${lib.getExe config.programs.zoxide.package} init zsh)"
        '';
      };

      starship.enable = true;

      fzf = {
        enable = true;
        enableBashIntegration = false;
        enableFishIntegration = false;
        enableNushellIntegration = false;
      };

      zoxide = {
        enable = true;
        enableBashIntegration = false;
        enableFishIntegration = false;
        enableNushellIntegration = false;
        # Initialised explicitly above; see the ordering note.
        enableZshIntegration = false;
      };

      bat.enable = true;
      fd.enable = true;
      ripgrep.enable = true;
      eza = {
        enable = true;
        icons = "auto";
        git = true;
      };

      git = {
        enable = true;
        settings.user = {
          name = "Marcos Melo";
          email = "marcosmelo@proton.me";
          # Refuse to guess an identity from the hostname/login for new repos.
          useConfigOnly = true;
        };
      };
    };
  };
}
