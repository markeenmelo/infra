{ config, inputs, ... }:
let
  limine = config.flake.modules.nixos.limine;
in
{
  # Authorized 2026-09-12: sole 100 GiB VirtIO disk, no serial/WWN/by-id.
  # Both canonical PCI and legacy virtio-pci aliases resolve to /dev/vda.
  # This identifies the VM attachment slot, not a unique physical disk:
  # recheck VM identity, topology, size and current use before every install.
  fleet.hosts.racknerd.module.fleet.installation = {
    osDevice = "/dev/disk/by-path/pci-0000:00:04.0";
    # Exact disk/reset approved; recovered fresh identities and native early
    # delivery tested. Ten kernel/initrd pairs total 409,738,090 bytes (< 2 GiB).
    storageReviewed = true;
  };
  flake.modules.nixos.racknerd-disko =
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
      fleet.bootstrap.missing = lib.optional (
        device != null
        && !lib.hasPrefix "/dev/disk/by-id/" device
        && !lib.hasPrefix "/dev/disk/by-path/pci-" device
      ) "Racknerd requires a reviewed whole-disk by-id or PCI by-path identity.";
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
            name:
            lib.mkForce (throw "Racknerd: ${name} requires a commissioned, reviewed OS-only installation.")
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
        # Use the same reviewed whole-disk identity for formatting and BIOS.
        biosDevice = device;
        partitionIndex = 1;
      };
      fileSystems."/nix".neededForBoot = true;
      fileSystems."/persist".neededForBoot = true;
    };
}
