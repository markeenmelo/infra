{
  flake.modules = {
    homeManager.base =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.jaq
          pkgs.rsync
          pkgs.unzip
          pkgs.dnsutils
          pkgs.glow
        ];
      };
  };
}
