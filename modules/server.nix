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
        tailscale.extraSetFlags = [ "--accept-dns=false" ];
        resolved.settings.Resolve = {
          DNS = [
            "194.242.2.2#dns.mullvad.net"
            "9.9.9.9#dns.quad9.net"
          ];
          DNSOverTLS = "yes";
        };
      };
    };
}
