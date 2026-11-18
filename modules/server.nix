{
  flake.modules.nixos.server =
    { lib, modulesPath, ... }:
    {
      imports = [ (modulesPath + "/profiles/minimal.nix") ];
      boot = {
        kernel.sysctl = {
          "kernel.sysrq" = 0;
          "kernel.io_uring_disabled" = 2;
        };
        kernelParams = [ "systemd.ssh_auto=no" ];
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
