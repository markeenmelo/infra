{
  flake.modules.nixos.server =
    {
      config,
      lib,
      modulesPath,
      pkgs,
      ...
    }:
    {
      imports = [ (modulesPath + "/profiles/minimal.nix") ];
      boot = {
        kernel.sysctl = {
          "kernel.sysrq" = 0;
          "kernel.io_uring_disabled" = 2;
          "kernel.yama.ptrace_scope" = 2;
          "vm.mmap_rnd_bits" = if pkgs.stdenv.hostPlatform.isAarch64 then 33 else 32;
          "vm.mmap_rnd_compat_bits" = 16;
        };
        kernelParams = [
          "randomize_kstack_offset=on"
          "systemd.ssh_auto=no"
        ]
        ++ lib.optional pkgs.stdenv.hostPlatform.isx86_64 "vsyscall=none";
        blacklistedKernelModules = [
          "appletalk"
          "atm"
          "ax25"
          "bluetooth"
          "caif"
          "can"
          "hfs"
          "hfsplus"
          "kcm"
          "netrom"
          "nfc"
          "phonet"
          "qrtr"
          "rose"
          "rxrpc"
          "smc"
          "udf"
          "x25"
        ];
        loader.limine.extraConfig = "graphics: no";
      };
      networking.useNetworkd = true;
      nix.gc = {
        automatic = lib.mkDefault true;
        dates = "weekly";
      };
      systemd.services.generations-clean = {
        description = "Delete all but the newest ten system generations";
        startAt = "weekly";
        before = [ "nix-gc.service" ];
        enableStrictShellChecks = true;
        path = [ config.nix.package ];
        serviceConfig.Type = "oneshot";
        script = "nix-env --profile /nix/var/nix/profiles/system --delete-generations +10";
      };
      nixpkgs.flake = {
        setFlakeRegistry = false;
        setNixPath = false;
      };
      programs = {
        bash.completion.enable = false;
        ssh.systemd-ssh-proxy.enable = false;
      };
      security.wrappers = lib.mkMerge [
        (lib.genAttrs
          [
            "mount"
            "newgidmap"
            "newgrp"
            "newuidmap"
            "sg"
            "su"
            "sudoedit"
            "umount"
          ]
          (_: {
            enable = false;
          })
        )
        {
          sudo = {
            group = lib.mkForce "deploy";
            permissions = lib.mkForce "u+rx,g+x";
          };
        }
      ];
      services = {
        getty.enable = false;
        logrotate.enable = true;
        openssh.allowSFTP = false;
        tailscale = {
          extraUpFlags = [
            "--reset"
            "--accept-dns=false"
          ];
          extraSetFlags = [ "--accept-dns=false" ];
        };
      };
      xdg.menus.enable = false;
    };
}
