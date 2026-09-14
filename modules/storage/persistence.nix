{ inputs, ... }:
{
  flake.modules.nixos.base =
    { lib, ... }:
    {
      imports = [
        inputs.disko.nixosModules.disko
        inputs.impermanence.nixosModules.impermanence
      ];
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
      fileSystems = {
        "/".neededForBoot = true;
        "/nix".neededForBoot = true;
        "/persist".neededForBoot = true;
      };
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
}
