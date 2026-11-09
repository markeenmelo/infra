{
  fleet.hosts.bastion.module =
    { lib, pkgs, ... }:
    let
      serials = map (id: lib.last (lib.splitString "_" id)) (lib.attrValues (import ./_disks.nix));
      datasets = {
        "/srv" = "apps/srv";
        "/srv/postgresql" = "apps/postgresql";
        "/srv/nixflix-state" = "apps/nixflix";
        "/srv/backup-thinkpad" = "apps/backup-thinkpad";
        "/srv/immich" = "tank/immich";
        "/srv/opencloud" = "tank/opencloud";
        "/srv/media" = "tank/media";
        "/var/lib/frigate" = "scratch/frigate";
      };
      pools = lib.unique (
        map (dataset: lib.head (lib.splitString "/" dataset)) (lib.attrValues datasets)
      );
      snapshots = hourly: monthly: {
        inherit hourly monthly;
        daily = 14;
      };
    in
    {
      fleet.carry = [ "zfs" ];
      networking.hostId = "ebbb349e";
      boot = {
        zfs.forceImportRoot = false;
        kernelParams = [ "zfs.zfs_arc_max=${toString (24 * 1024 * 1024 * 1024)}" ];
      };
      fileSystems = lib.mkMerge [
        (lib.mapAttrs (mount: device: {
          inherit device;
          fsType = "zfs";
          options = [
            "nofail"
            "nosuid"
            "nodev"
          ]
          ++ lib.optional (mount == "/srv/media") "noexec";
        }) datasets)
        {
          "/mnt/backup" = {
            # the USB backup disk's ext4 filesystem, recorded by the old generation
            device = "/dev/disk/by-uuid/299d5130-226c-4d2f-b677-d4613da171db";
            fsType = "ext4";
            options = [
              "nofail"
              "nosuid"
              "nodev"
              "noexec"
              "x-systemd.automount"
              "x-systemd.idle-timeout=30min"
              "x-systemd.device-timeout=5s"
              "x-systemd.mount-timeout=30s"
            ];
          };
        }
      ];
      systemd = {
        tmpfiles.rules = [
          "d /persist/zfs 0700 root root -"
          "z /persist/zfs/*.key 0400 root root -"
        ];
        services = lib.genAttrs (map (pool: "zfs-import-${pool}") pools) (_: {
          restartIfChanged = false;
        });
        timers.sanoid.timerConfig.Persistent = true;
      };
      services = {
        udev.extraRules = ''
          ACTION=="add", SUBSYSTEM=="block", KERNEL=="sd[a-z]", ENV{ID_SERIAL_SHORT}=="${lib.concatStringsSep "|" serials}", RUN+="${lib.getExe pkgs.hdparm} -S 242 /dev/%k"
        '';
        zfs.autoScrub.enable = true;
        sanoid = {
          enable = true;
          datasets = lib.mkMerge [
            (lib.genAttrs [ "apps/srv" "apps/postgresql" "apps/nixflix" ] (_: snapshots 24 3))
            (lib.genAttrs [ "tank/immich" "tank/opencloud" ] (_: snapshots 0 3))
            { "apps/backup-thinkpad" = snapshots 0 0; }
          ];
        };
      };
    };
}
