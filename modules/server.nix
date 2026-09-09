{ config, ... }:
{
  flake.modules.nixos.server = {
    imports = [ config.flake.modules.nixos.ssh ];
    documentation.nixos.enable = false;
    fleet.logging.persistent = true;
    networking.nftables.enable = true;
    systemd.coredump.enable = false;
    # Conservative hardening, without a different kernel/profile that could
    # break ZFS, virtualization, hardware drivers or console recovery.
    boot.kernel.sysctl = {
      "kernel.kptr_restrict" = 2;
      "kernel.dmesg_restrict" = 1;
      "kernel.yama.ptrace_scope" = 1;
      "fs.protected_fifos" = 2;
      "fs.protected_regular" = 2;
      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.default.accept_redirects" = 0;
      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;
      "net.ipv6.conf.all.accept_redirects" = 0;
      "net.ipv6.conf.default.accept_redirects" = 0;
    };
  };
}
