{
  flake.modules = {
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
