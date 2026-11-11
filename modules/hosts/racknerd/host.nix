{ config, ... }:
{
  fleet.hosts.racknerd.tailnetAddress = "100.96.133.3";
  fleet.hosts.racknerd.telemetry = {
    metrics = 9095;
    logs = 3102;
  };
  fleet.hosts.racknerd.module = {
    imports = with config.flake.modules.nixos; [
      server
      edge
      crowdsec
      cache
      telemetry
    ];
    security.lockKernelModules = true;
    # shortcut: the modules racknerd's firewall, Tailscale and CrowdSec loaded at runtime when listed, add one here when a deploy fails on a module that cannot load
    boot.kernelModules = [
      "tun"
      "nft_chain_nat"
      "nft_compat"
      "nft_ct"
      "nft_fib_inet"
      "nft_reject_inet"
      "xt_MASQUERADE"
      "xt_connmark"
      "xt_conntrack"
      "xt_mark"
      "xt_tcpudp"
      "tcp_diag"
      "udp_diag"
    ];
    system.stateVersion = "26.05";
  };
}
