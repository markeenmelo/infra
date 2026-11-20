let
  common = {
    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      connect-timeout = 5;
      fallback = true;
    };
  };
  nh =
    { lib, ... }:
    {
      programs.nh = {
        enable = true;
        clean = {
          enable = true;
          extraArgs = lib.mkDefault "--keep 10 --keep-since 14d";
        };
      };
    };
in
{
  flake.modules.nixos.desktop = nh;

  flake.modules.nixos.base =
    { config, lib, ... }:
    {
      imports = [ common ];
      nix = {
        channel.enable = false;
        settings = {
          allowed-users = [ "@wheel" ];
          auto-optimise-store = true;
        };
      };
      documentation.enable = false;
      time.timeZone = "America/Toronto";
      boot = {
        loader = {
          efi.canTouchEfiVariables = lib.mkDefault true;
          limine = {
            enable = lib.mkDefault true;
            panicOnChecksumMismatch = true;
            maxGenerations = lib.mkDefault 10;
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
          "dev.tty.legacy_tiocsti" = 0;
          "net.ipv4.tcp_rfc1337" = 1;
        };
      };
      security.protectKernelImage = true;
      systemd.coredump.settings.Coredump.Storage = "none";
      environment = {
        defaultPackages = [ ];
        stub-ld.enable = false;
      };
      system.disableInstallerTools = true;
      programs.nano.enable = false;
      networking.useDHCP = false;
      services.resolved.settings.Resolve = {
        LLMNR = false;
        MulticastDNS = false;
      };
      services.journald.settings.Journal = {
        Storage = lib.mkDefault "persistent";
        SystemMaxUse = "256M";
      };
      preservation.preserveAt."/persist".directories = lib.mkIf (
        config.services.journald.settings.Journal.Storage == "persistent"
      ) [ "/var/log/journal" ];
    };
}
