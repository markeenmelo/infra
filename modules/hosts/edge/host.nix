{ config, ... }:
{
  fleet.hosts.edge = {
    system = "aarch64-linux";
    tailnetAddress = "100.78.192.61";
    publicAddress = "40.233.65.50";
    telemetry = {
      metrics = 9097;
      logs = 3105;
    };
    unlock = {
      port = 22022;
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKrNoF3lppFQJ7UcGh0MGmmboXvaj4bb6EHl+G5ku0he";
    };
    module = {
      imports = with config.flake.modules.nixos; [
        server
        telemetry
        unlock
        passthrough
        crowdsec-bouncer
        (
          {
            config,
            modulesPath,
            pkgs,
            ...
          }:
          {
            imports = [ (modulesPath + "/profiles/perlless.nix") ];
            boot.kernelPackages = pkgs.linuxPackages;
            networking.firewall = {
              allowPing = false;
              extraInputRules = ''
                iifname "${config.services.tailscale.interfaceName}" icmp type echo-request accept
              '';
            };
            services.userborn.passwordFilesLocation = "/var/lib/nixos";
          }
        )
      ];
      boot.blacklistedKernelModules = [
        "vmw_vsock_virtio_transport"
        "vsock"
        "vsock_loopback"
      ];
      boot.kernel.sysctl."net.ipv4.tcp_mtu_probing" = 1;
      boot.kernelParams = [
        "debugfs=off"
        "init_on_free=1"
      ];
      fonts.fontconfig.enable = false;
      services.journald.settings.Journal = {
        Storage = "volatile";
        RuntimeMaxUse = "32M";
      };
      systemd.tmpfiles.settings.journal."/persist/var/log/journal".R = { };
      security.lockKernelModules = true;
      # shortcut: the modules edge's firewall, Tailscale and the CrowdSec bouncer load at runtime, add one here and deploy with --boot then reboot when a unit fails on a module that cannot load, since the lock holds until reboot
      boot.kernelModules = [
        "nft_chain_nat"
        "nft_compat"
        "nft_ct"
        "nft_fib_inet"
        "xt_MASQUERADE"
        "xt_connmark"
        "xt_conntrack"
        "xt_mark"
        "xt_tcpudp"
        "tcp_diag"
        "udp_diag"
      ];
      system.stateVersion = "26.11";
    };
  };
}
