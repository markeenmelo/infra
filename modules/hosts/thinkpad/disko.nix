{ config, inputs, ... }:
let
  limine = config.flake.modules.nixos.limine;
in
{
  # Fresh candidate only. Never activate this over the running LUKS/LVM disk.
  fleet.hosts.thinkpad.module.fleet.installation.osDevice =
    "/dev/disk/by-id/nvme-eui.00a075013a594e93";

  flake.modules.nixos.thinkpad-disko =
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
            lib.mkForce (throw "ThinkPad: ${name} requires a commissioned, reviewed OS-only installation.")
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
            assert lib.assertMsg (device != null) "ThinkPad OS device is unresolved.";
            device;
          content = {
            type = "gpt";
            partitions = {
              boot = {
                type = "EF00";
                size = "4G";
                priority = 1;
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = [ "umask=0077" ];
                };
              };
              swap = {
                size = "8G";
                priority = 2;
                content.type = "swap";
              };
              state = {
                size = "100%";
                content = {
                  type = "btrfs";
                  subvolumes = lib.genAttrs [ "nix" "persist" "home" ] (name: {
                    mountpoint = "/${name}";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                      "nodiscard"
                    ];
                  });
                };
              };
            };
          };
        };
      };
      services.lvm.enable = false;
      boot.resumeDevice = "";
      boot.loader = {
        efi.canTouchEfiVariables = true; # Proposed policy; fresh boot review pending.
        limine = {
          enable = true;
          efiSupport = true;
          biosSupport = false;
        };
      };
      systemd.sleep.settings.Sleep = {
        AllowHibernation = false;
        AllowHybridSleep = false;
        AllowSuspendThenHibernate = false;
      };
      fleet.workstation.homePersistence = "filesystem";
      fileSystems = {
        "/home".neededForBoot = true;
        "/nix".neededForBoot = true;
        "/persist".neededForBoot = true;
      };
    };
}
