{ inputs, ... }:
{
  flake.modules.nixos.base =
    { lib, ... }:
    let
      inherit (lib) mkOption types;
    in
    {
      imports = [
        inputs.disko.nixosModules.disko
        inputs.impermanence.nixosModules.impermanence
      ];
      options.fleet = {
        installation = {
          osDevice = mkOption {
            type = types.nullOr (types.strMatching "/dev/disk/by-(id|path)/[a-zA-Z0-9._:+-]+");
            default = null;
            apply =
              device:
              assert lib.assertMsg (
                device == null || builtins.match ".*-part[0-9]+" device == null
              ) "The installation device must be a whole OS disk, not a partition.";
              device;
            description = "Whole OS disk identity for the per-host disko layout. Each layout restricts its identifier policy; only Racknerd permits a PCI by-path exception when no serial/by-id exists.";
          };
        };
      };
      config = {
        disko.devices = {
          lvm_vg = lib.mkForce { };
          mdadm = lib.mkForce { };
          zpool = lib.mkForce { };
          bcachefs_filesystems = lib.mkForce { };
          nodev."/" = {
            fsType = "tmpfs";
            mountOptions = [
              "mode=755"
              "size=25%"
            ];
          };
        };
        services.lvm.enable = false;
        fileSystems."/persist".neededForBoot = true;
        environment.persistence."/persist" = {
          hideMounts = true;
          directories = [
            "/var/lib/nixos"
            "/var/lib/systemd/timers"
            {
              directory = "/var/lib/systemd/timesync";
              user = "systemd-timesync";
              group = "systemd-timesync";
              mode = "0755";
            }
          ];
          files = [
            "/etc/machine-id"
            "/var/lib/systemd/random-seed"
          ];
        };
      };
    };
}
