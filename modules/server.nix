{
  flake.modules.nixos.server =
    { modulesPath, ... }:
    {
      imports = [ (modulesPath + "/profiles/minimal.nix") ];
      boot = {
        kernel.sysctl = {
          "kernel.sysrq" = 0;
          "kernel.io_uring_disabled" = 2;
        };
        loader.limine.extraConfig = "graphics: no";
      };
      networking.useNetworkd = true;
      services = {
        logrotate.enable = true;
        tailscale = {
          extraUpFlags = [
            "--reset"
            "--accept-dns=false"
          ];
          extraSetFlags = [ "--accept-dns=false" ];
        };
      };
    };
}
