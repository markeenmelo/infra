{
  flake.modules.homeManager.desktop.programs.git.enable = true;

  fleet.hosts.thinkpad.module.home-manager.users.marcos.programs.git.settings.user = {
    name = "Marcos Melo";
    email = "marcosmelo@proton.me";
    useConfigOnly = true;
  };
}
