{
  flake.modules.homeManager.base.programs = {
    git = {
      enable = true;
      settings = {
        user = {
          name = "Marcos Melo";
          email = "8158196+markeenmelo@users.noreply.github.com";
        };
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
      };
    };
    gh.enable = true;
  };
}
