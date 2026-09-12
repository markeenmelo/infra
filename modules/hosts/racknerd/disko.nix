{ config, inputs, ... }:
let
  limine = config.flake.modules.nixos.limine;
in
{
  # No by-id was observed. The old /dev/vda bootloader exception does not
  # authorize formatting: installation.osDevice stays null pending review.
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
        # Retain the observed bootloader-only identity while the fresh format
        # target is unresolved. No build/install output is permitted meanwhile.
        biosDevice = if device == null then "/dev/vda" else device;
        partitionIndex = 1;
      };
      fileSystems."/nix".neededForBoot = true;
      fileSystems."/persist".neededForBoot = true;
    };
}
