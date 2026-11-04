{ config, inputs, ... }:
{
  flake.modules = {
    darwin.base = {
      imports = [ inputs.home-manager.darwinModules.home-manager ];
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users.marcos = config.flake.modules.homeManager.base;
      };
    };
    homeManager.base.programs.zsh.enable = true;
  };
}
