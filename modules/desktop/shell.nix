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
        initContent = lib.mkOrder 2000 ''
          eval "$(${lib.getExe config.programs.zoxide.package} init zsh)"
        '';
      };

      starship.enable = true;

      direnv = {
        enable = true;
        enableBashIntegration = false;
        enableFishIntegration = false;
        enableNushellIntegration = false;
      };

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
    };
  };
}
