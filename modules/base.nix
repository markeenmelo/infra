{
  flake.modules.nixos.base =
    { lib, ... }:
    {
      nix = {
        channel.enable = false;
        settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          allowed-users = [ "@wheel" ];
          auto-optimise-store = true;
          connect-timeout = 5;
          fallback = true;
        };
      };
      documentation.enable = false;
      programs.nh = {
        enable = true;
        clean = {
          enable = true;
          extraArgs = "--keep 10 --keep-since 14d";
        };
      };
      time.timeZone = "America/Toronto";
      boot = {
        loader = {
          efi.canTouchEfiVariables = lib.mkDefault true;
          limine = {
            enable = lib.mkDefault true;
            panicOnChecksumMismatch = true;
            maxGenerations = 10;
          };
        };
        bcache.enable = false;
        kexec.enable = false;
        kernelParams = [
          "slab_nomerge"
          "page_alloc.shuffle=1"
        ];
        blacklistedKernelModules = [
          "sctp"
          "rds"
          "tipc"
          "cramfs"
          "freevxfs"
          "jffs2"
        ];
        kernel.sysctl = {
          "kernel.kptr_restrict" = 2;
          "fs.protected_fifos" = 2;
          "fs.protected_regular" = 2;
          "net.ipv4.conf.all.accept_redirects" = 0;
          "net.ipv4.conf.default.accept_redirects" = 0;
          "net.ipv4.conf.all.send_redirects" = 0;
          "net.ipv4.conf.default.send_redirects" = 0;
          "net.ipv4.conf.all.log_martians" = 1;
          "net.ipv4.conf.default.log_martians" = 1;
          "kernel.unprivileged_bpf_disabled" = 1;
          "net.core.bpf_jit_harden" = 2;
          "dev.tty.ldisc_autoload" = 0;
          "net.ipv4.tcp_rfc1337" = 1;
        };
      };
      services.journald.settings.Journal = {
        Storage = "persistent";
        SystemMaxUse = "256M";
      };
      preservation.preserveAt."/persist".directories = [ "/var/log/journal" ];
    };
}
