{ config, inputs, ... }:
{
  flake.modules = {
    darwin.base = {
      imports = [ inputs.home-manager.darwinModules.home-manager ];
      home-manager = {
        backupFileExtension = "backup";
        useGlobalPkgs = true;
        useUserPackages = true;
        users.marcos = config.flake.modules.homeManager.base;
      };
    };
    homeManager.base =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.jq
          pkgs.rsync
          pkgs.unzip
          pkgs.dnsutils
          pkgs.glow
        ];
      };
  };
}
