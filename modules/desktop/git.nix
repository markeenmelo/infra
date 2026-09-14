{
  flake.modules.homeManager.desktop.programs = {
    git.enable = true;
    gh = {
      enable = true;
      gitCredentialHelper.enable = true;
    };
  };

  fleet.hosts.thinkpad.module.home-manager.users.marcos.programs.git.settings.user = {
    name = "Marcos Melo";
    email = "marcosmelo@proton.me";
    useConfigOnly = true;
  };
}
