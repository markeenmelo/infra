{ lib, ... }:
let
  # Observed legacy dataset mounts, 2026-09-09. No pool creation, dataset
  # creation, properties, upgrades, repartitioning, shares or data migration.
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
    boot.zfs = {
      devNodes = "/dev/disk/by-id";
      forceImportRoot = false;
      forceImportAll = false;
      # NixOS derives the named tank import from the legacy filesystem entries.
      extraPools = [ ];
    };
    fileSystems = lib.mapAttrs (_: device: {
      inherit device;
      fsType = "zfs";
    }) datasets;
    # Preserve the existing monthly scrub policy, not a backup/restore claim.
    services.zfs.autoScrub = {
      enable = true;
      pools = [ "tank" ];
      interval = "monthly";
      randomizedDelaySec = "6h";
    };
    # nas.storageReviewed stays false: verify pool GUID 7246454901288299061,
    # both member serials, restore, and upstream versus previous strict import
    # behavior before approving this transition. No service may use /srv until
    # its exact required mount is present; no application is enabled here.
  };
}
