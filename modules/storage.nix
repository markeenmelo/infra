{ inputs, ... }:
{
  flake.modules.nixos.base =
    {
      config,
      lib,
      utils,
      ...
    }:
    let
      root = config.fileSystems."/".device;
      btrfs = {
        type = "btrfs";
        subvolumes = lib.genAttrs [ "root" "nix" "persist" ] (name: {
          mountpoint = if name == "root" then "/" else "/${name}";
          mountOptions = [
            "compress=zstd"
            "noatime"
          ];
        });
      };
    in
    {
      imports = [
        inputs.disko.nixosModules.disko
        inputs.preservation.nixosModules.preservation
      ];
      options.fleet.encryptState = lib.mkOption {
        type = lib.types.bool;
        description = "Whether the state partition is LUKS, opened at boot by its TPM2 token or the passphrase.";
      };
      config = {
        disko.devices.disk.os.content = {
          type = "gpt";
          partitions = {
            boot = {
              type = lib.mkDefault "EF00";
              size = lib.mkDefault "2G";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            state = {
              size = "100%";
              content =
                if config.fleet.encryptState then
                  {
                    type = "luks";
                    name = "state";
                    settings.allowDiscards = true;
                    content = btrfs;
                  }
                else
                  btrfs;
            };
          };
        };
        fileSystems."/persist".neededForBoot = true;
        services.btrfs.autoScrub = {
          enable = true;
          fileSystems = [ "/persist" ];
        };

        boot.initrd.systemd.services.root-reset = {
          wantedBy = [ "initrd.target" ];
          requires = [ "${utils.escapeSystemdPath root}.device" ];
          after = [ "${utils.escapeSystemdPath root}.device" ];
          before = [ "sysroot.mount" ];
          unitConfig.DefaultDependencies = "no";
          serviceConfig.Type = "oneshot";
          enableStrictShellChecks = true;
          script = ''
            mkdir -p /btrfs
            mount -t btrfs -o subvol=/ ${root} /btrfs
            if [ -e /btrfs/root ]; then
              btrfs subvolume delete --recursive /btrfs/root
            fi
            btrfs subvolume create /btrfs/root
            umount /btrfs
          '';
        };

        preservation = {
          enable = true;
          preserveAt."/persist" = {
            directories = [
              {
                directory = "/var/lib/nixos";
                inInitrd = true;
              }
              "/var/lib/systemd/timers"
            ];
            files = [
              {
                file = "/etc/machine-id";
                inInitrd = true;
              }
              {
                file = "/var/lib/systemd/random-seed";
                how = "symlink";
                inInitrd = true;
                configureParent = true;
              }
            ];
          };
        };
        systemd.suppressedSystemUnits = [ "systemd-machine-id-commit.service" ];
      };
    };
}
