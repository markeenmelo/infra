{ config, inputs, ... }:
let
  limine = config.flake.modules.nixos.limine;
in
{
  # Authorized pre-install review, 2026-09-12: live serial 511250213117000312,
  # UEFI/console, NVMe-only replacement, NAS backup/restore and distinct recovered
  # credentials. Kernel+initrd: 55,580,037 bytes; ten copies fit the 2 GiB ESP.
  # This is not boot acceptance. tank/SATA/USB remain outside this layout.
  fleet.hosts.bastion.module.fleet.installation = {
    osDevice = "/dev/disk/by-id/nvme-eui.6479a7a2ea200e8e";
    storageReviewed = true;
  };

  flake.modules.nixos.bastion-disko =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      device = config.fleet.installation.osDevice;
      blocked =
        !config.fleet.bootstrap.approved
        || config.fleet.bootstrap.missing != [ ]
        || builtins.attrNames config.disko.devices.disk != [ "os" ]
        || config.disko.devices.disk.os.device != device;
    in
    {
      imports = [
        inputs.disko.nixosModules.disko
        limine
      ];
      # Even empty legacy scripts may unmount /mnt. No pending public output.
      system.build = lib.mkIf blocked (
        lib.genAttrs
          (
            builtins.attrNames (config.disko.devices._scripts { inherit pkgs; })
            ++ [
              "disko"
              "diskoNoDeps"
              "installTest"
              "vmWithDisko"
              "diskoImages"
              "diskoImagesScript"
            ]
          )
          (
            name: lib.mkForce (throw "Bastion: ${name} requires a commissioned, reviewed OS-only installation.")
          )
      );
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
        efi.canTouchEfiVariables = true; # Proposed policy; fresh boot review pending.
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
