{ lib, ... }:
let
  # Observed legacy mount facts, 2026-09-09. No pool/filesystem creation,
  # property migration, upgrades, repartitioning, shares or data migration.
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
    # NixOS derives tank import from the legacy entries. Preserve non-force
    # policy; this is not independent GUID/member/health verification.
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
      # User-selected native defaults: retain 4 frequent, 24 hourly, 7 daily,
      # 4 weekly and 12 monthly. zfstools uses dataset properties to opt in;
      # this declaration neither sets properties nor proves any dataset opted in.
      autoSnapshot.enable = true;
    };
    # nas.storageReviewed stays false: verify pool GUID 7246454901288299061,
    # both member serials, restore, and upstream versus previous strict import
    # behavior before approving this transition. Also review inherited snapshot
    # opt-ins, existing names/holds, pruning and free space before activation.
    # No application may use /srv until its exact required mount is present.
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
