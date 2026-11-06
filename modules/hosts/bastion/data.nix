{
  fleet.hosts.bastion.module =
    { lib, pkgs, ... }:
    let
      datasets = {
        "/srv" = "apps/srv";
        "/srv/postgresql" = "apps/postgresql";
        "/srv/nixflix-state" = "apps/nixflix";
        "/srv/backup-thinkpad" = "apps/backup-thinkpad";
        "/srv/immich" = "tank/immich";
        "/srv/nextcloud" = "tank/nextcloud";
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
      fileSystems = lib.mapAttrs (mount: device: {
        inherit device;
        fsType = "zfs";
        options = [
          "nofail"
          "nosuid"
          "nodev"
        ]
        ++ lib.optional (mount == "/srv/media") "noexec";
      }) datasets;
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
          ACTION=="add", SUBSYSTEM=="block", KERNEL=="sd[a-z]", ENV{ID_SERIAL_SHORT}=="ZW63V4FM|2270A00MFZ1G", RUN+="${lib.getExe pkgs.hdparm} -S 242 /dev/%k"
        '';
        zfs.autoScrub.enable = true;
        sanoid = {
          enable = true;
          datasets = lib.mkMerge [
            (lib.genAttrs [ "apps/srv" "apps/postgresql" "apps/nixflix" ] (_: snapshots 24 3))
            (lib.genAttrs [ "tank/immich" "tank/nextcloud" "tank/opencloud" ] (_: snapshots 0 3))
            { "apps/backup-thinkpad" = snapshots 0 0; }
          ];
        };
      };
    };
}
