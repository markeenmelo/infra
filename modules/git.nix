let
  user = {
    name = "Marcos Melo";
    email = "8158196+markeenmelo@users.noreply.github.com";
  };
in
{
  flake.modules.nixos.git.programs.git = {
    enable = true;
    config = { inherit user; };
  };
  flake.modules.homeManager.base.programs = {
    git = {
      enable = true;
      settings = {
        inherit user;
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
        difftool.prompt = false;
      };
    };
    gh.enable = true;
    difftastic = {
      enable = true;
      git = {
        enable = true;
        mode = "difftool";
      };
    };
  };
}
