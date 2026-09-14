{ config, inputs, ... }:
let
  limine = config.flake.modules.nixos.limine;
in
{
  fleet.hosts.racknerd.module.fleet.installation.osDevice = "/dev/disk/by-path/pci-0000:00:04.0";
  flake.modules.nixos.racknerd-disko =
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
            assert lib.assertMsg (device != null) "Racknerd fresh provisioning identifier remains unresolved.";
            device;
          content = {
            type = "gpt";
            partitions = {
              BIOS = {
                type = "EF02";
                size = "1M";
                priority = 1;
              };
              boot = {
                type = "0700";
                size = "2G";
                priority = 2;
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
      boot.loader.limine = {
        enable = true;
        efiSupport = false;
        biosSupport = true;
        biosDevice = device;
        partitionIndex = 1;
      };
      fileSystems."/nix".neededForBoot = true;
      fileSystems."/persist".neededForBoot = true;
    };
}
