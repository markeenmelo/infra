{ config, inputs, ... }:
let
  limine = config.flake.modules.nixos.limine;
in
{
  fleet.hosts.bastion.module.fleet.installation.osDevice =
    "/dev/disk/by-id/nvme-eui.6479a7a2ea200e8e";

  flake.modules.nixos.bastion-disko =
    {
      config,
      lib,
      ...
    }:
    let
      device = config.fleet.installation.osDevice;
    in
    {
      imports = [
        inputs.disko.nixosModules.disko
        limine
      ];
      disko.devices = {
        lvm_vg = lib.mkForce { };
        mdadm = lib.mkForce { };
        zpool = lib.mkForce { };
        bcachefs_filesystems = lib.mkForce { };
        disk.os = {
          type = "disk";
          device =
            assert lib.assertMsg (device != null) "Bastion OS device is unresolved.";
            device;
          content = {
            type = "gpt";
            partitions = {
              boot = {
                type = "EF00";
                size = "2G";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = [ "umask=0077" ];
                };
              };
              state = {
                size = "100%";
                content = {
                  type = "btrfs";
                  subvolumes = lib.genAttrs [ "nix" "persist" ] (name: {
                    mountpoint = "/${name}";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  });
                };
              };
            };
          };
        };
      };
      services.lvm.enable = false;
      boot.loader = {
        efi.canTouchEfiVariables = true;
        limine = {
          enable = true;
          efiSupport = true;
          biosSupport = false;
        };
      };
      fileSystems."/nix".neededForBoot = true;
      fileSystems."/persist".neededForBoot = true;
    };
}
