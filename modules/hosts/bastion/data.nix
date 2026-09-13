{ lib, ... }:
let
  datasets = {
    "/srv" = "tank/srv";
    "/srv/containers" = "tank/srv/containers";
    "/srv/frigate" = "tank/srv/frigate";
    "/srv/immich" = "tank/srv/immich";
    "/srv/nextcloud" = "tank/srv/nextcloud";
    "/srv/nixflix" = "tank/srv/nixflix";
    "/srv/yuvomi" = "tank/srv/yuvomi";
    "/srv/offsite-stage" = "tank/offsite-stage";
  };
in
{
  fleet.hosts.bastion.module = {
    networking.hostId = "ebbb349e";
    boot.supportedFilesystems = [ "zfs" ];
    boot.zfs.forceImportRoot = false;
    fileSystems = lib.mapAttrs (_: device: {
      inherit device;
      fsType = "zfs";
    }) datasets;
    services.zfs = {
      autoScrub = {
        enable = true;
        pools = [ "tank" ];
        interval = "monthly";
      };
      autoSnapshot.enable = true;
    };
    fleet.nas.storageReviewed = true;
  };

  fleet.validation.hostChecks.nasMaintenance =
    { name, system, ... }:
    let
      cfg = system.config;
      retention = {
        frequent = 4;
        hourly = 24;
        daily = 7;
        weekly = 4;
        monthly = 12;
      };
      snapshotter = system.pkgs.zfstools.override { zfs = cfg.boot.zfs.package; };
    in
    assert lib.assertMsg (
      if name != "bastion" then
        !cfg.services.zfs.autoScrub.enable && !cfg.services.zfs.autoSnapshot.enable
      else
        cfg.services.zfs.autoScrub.enable
        && cfg.services.zfs.autoScrub.pools == [ "tank" ]
        && cfg.services.zfs.autoScrub.interval == "monthly"
        && cfg.systemd.timers.zfs-scrub.timerConfig.OnCalendar == "monthly"
        && cfg.systemd.timers.zfs-scrub.timerConfig.RandomizedDelaySec == "6h"
        && lib.hasInfix "/bin/zpool scrub -w tank" cfg.systemd.services.zfs-scrub.script
        && cfg.services.zfs.autoSnapshot.enable
        && cfg.services.zfs.autoSnapshot.flags == "-k -p"
        && lib.all (
          interval:
          let
            job = cfg.systemd.services."zfs-snapshot-${interval}";
            timer = cfg.systemd.timers."zfs-snapshot-${interval}";
          in
          cfg.services.zfs.autoSnapshot.${interval} == retention.${interval}
          &&
            job.serviceConfig.ExecStart
            == "${snapshotter}/bin/zfs-auto-snapshot -k -p ${interval} ${toString retention.${interval}}"
          && lib.elem "zfs-import.target" job.after
          && timer.timerConfig.OnCalendar == (if interval == "frequent" then "*:0,15,30,45" else interval)
          && lib.elem "timers.target" timer.wantedBy
        ) (builtins.attrNames retention)
        && builtins.length (builtins.attrNames datasets) == 8
        &&
          lib.mapAttrs (_: fs: fs.device) (lib.filterAttrs (_: fs: fs.fsType == "zfs") cfg.fileSystems)
          == datasets
        && cfg.boot.zfs.extraPools == [ ]
        && !cfg.boot.zfs.forceImportRoot
        && !cfg.boot.zfs.forceImportAll
    ) "${name}: Bastion-only native snapshot/scrub policy or preserved legacy mounts regressed";
    true;
}
