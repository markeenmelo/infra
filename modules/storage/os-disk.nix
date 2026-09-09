{ inputs, ... }:
{
  flake.modules.nixos.os-disk =
    { config, lib, ... }:
    let
      inherit (lib) mkOption types;
      cfg = config.fleet.osDisk;
      layoutKnown =
        cfg.device != null && cfg.bootMode != null && (cfg.bootMode != "uefi" || cfg.espSize != null);
    in
    {
      imports = [ inputs.disko.nixosModules.disko ];
      options.fleet.osDisk = {
        device = mkOption {
          type = types.nullOr (types.strMatching "/dev/disk/by-id/[a-zA-Z0-9._:+-]+");
          default = null;
          description = "Verified whole OS disk by-id path, NEVER a NAS data disk. No fabricated example device.";
        };
        confirmed = mkOption {
          type = types.bool;
          default = false;
          description = "Explicitly approve the OS disk/layout destructive boundary after serial and backup review.";
        };
        bootMode = mkOption {
          type = types.nullOr (
            types.enum [
              "uefi"
              "bios"
            ]
          );
          default = null;
          description = "Firmware mode verified on this machine, not inferred from vendor or model.";
        };
        efiCanTouchVariables = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "UEFI: explicitly choose whether bootctl may write NVRAM entries. false relies on firmware fallback boot; verify it on this machine.";
        };
        espSize = mkOption {
          type = types.nullOr (types.strMatching "[1-9][0-9]*[MG]");
          default = null;
          # Check the merged option, including when disko scripts are evaluated directly.
          apply =
            size:
            assert lib.assertMsg (
              size == null || lib.hasSuffix "G" size || lib.toInt (lib.removeSuffix "M" size) >= 512
            ) "fleet.osDisk.espSize must be at least 512M (512 MiB).";
            size;
          description = ''
            Deliberately sized EFI system partition (UEFI only), at least 512M (512 MiB).
            M/G denote MiB/GiB. This is a safety floor, not a capacity guarantee:
            review space for the actual kernel/initrd and retained generations.
          '';
        };
      };
      config = {
        fleet.bootstrap.missing =
          lib.optional (cfg.device == null) "Supply fleet.osDisk.device (verified whole OS disk by-id)."
          ++ lib.optional (!cfg.confirmed) "Review backups/layout and set fleet.osDisk.confirmed."
          ++ lib.optional (cfg.bootMode == null) "Select fleet.osDisk.bootMode after checking the firmware."
          ++ lib.optional (
            cfg.bootMode == "uefi" && cfg.espSize == null
          ) "Size fleet.osDisk.espSize explicitly."
          ++ lib.optional (
            cfg.bootMode == "uefi" && cfg.efiCanTouchVariables == null
          ) "Choose fleet.osDisk.efiCanTouchVariables and verify UEFI boot entry/fallback behavior.";

        # This baseline owns ONLY the OS disk. It cannot be extended with NAS disks.
        # A different layout needs a separately reviewed capability, not another disk here.
        disko.devices.disk = lib.mkForce (
          lib.optionalAttrs layoutKnown {
            os = {
              type = "disk";
              device =
                assert lib.assertMsg cfg.confirmed "Refusing to generate disko scripts: OS disk not confirmed.";
                assert lib.assertMsg (
                  builtins.match ".*-part[0-9]+" cfg.device == null
                ) "OS disk must be a whole disk, not a partition.";
                cfg.device;
              content = {
                type = "gpt";
                partitions =
                  lib.optionalAttrs (cfg.bootMode == "uefi") {
                    ESP = {
                      type = "EF00";
                      size = cfg.espSize;
                      content = {
                        type = "filesystem";
                        format = "vfat";
                        mountpoint = "/boot";
                        mountOptions = [ "umask=0077" ];
                      };
                    };
                  }
                  // lib.optionalAttrs (cfg.bootMode == "bios") {
                    # GPT BIOS boot metadata, not a filesystem or a guessed disk size.
                    BIOS = {
                      type = "EF02";
                      size = "1M";
                    };
                  }
                  // {
                    state = {
                      size = "100%";
                      content = {
                        type = "btrfs";
                        subvolumes = {
                          "@nix".mountpoint = "/nix";
                          "@persist".mountpoint = "/persist";
                        }
                        // lib.optionalAttrs (cfg.bootMode == "bios") {
                          "@boot".mountpoint = "/boot";
                        };
                      };
                    };
                  };
              };
            };
          }
        );
        boot.loader = {
          # Disko derives GRUB devices from the EF02 partition; do not add it twice.
          grub.enable = cfg.bootMode == "bios";
          systemd-boot.enable = cfg.bootMode == "uefi";
          efi.canTouchEfiVariables = cfg.efiCanTouchVariables == true;
        };
        # Without the real backing filesystem there is intentionally no /persist or /nix mount.
        fileSystems = lib.mkIf layoutKnown {
          "/persist".neededForBoot = true;
          "/nix".neededForBoot = true;
        };
      };
    };
}
