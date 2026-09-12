{ lib, ... }:
let
  importScript = builtins.readFile ./import-bastion-tank.sh;
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
  fleet.hosts.bastion.module = { config, pkgs, ... }: {
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
    # Preserve the installed strict importer, not upstream's degraded fallback.
    # Keep native requiredBy/before edges for every legacy dataset mount.
    systemd.services.zfs-import-tank = {
      path = [
        config.boot.zfs.package
        pkgs.gawk
        pkgs.jq
        pkgs.coreutils
      ];
      environment = {
        BASTION_TANK_POOL = "tank";
        BASTION_TANK_POOL_GUID = "7246454901288299061";
        BASTION_TANK_TOP_GUID = "10090352225522454630";
        BASTION_TANK_LEAF_GUIDS = "10490442266801898687 10971089219668578942";
        BASTION_TANK_MEMBER_ALIASES = "/dev/disk/by-id/ata-ST4000VN006-3CW104_ZW63V4FM-part1 /dev/disk/by-id/ata-TOSHIBA_HDWG440_2270A00MFZ1G-part1";
        BASTION_TANK_DATASETS = lib.concatStringsSep " " (builtins.attrValues datasets);
        BASTION_TANK_DEV_NODES = "/dev/disk/by-id";
        BASTION_TANK_IMPORT_ATTEMPTS = "60";
      };
      script = lib.mkForce importScript;
    };
    # 2026-09-11: live identities/datasets verified; operator confirmed tested
    # NAS backups/recovery and explicitly chose the existing strict policy.
    # This is pre-activation review, not a new import or boot test.
    fleet.nas.storageReviewed = true;
  };

  fleet.validation.hostChecks.bastionImport =
    { name, system, ... }:
    let
      cfg = system.config;
      service = cfg.systemd.services.zfs-import-tank;
    in
    name != "bastion"
    || (
      assert lib.assertMsg (
        service.script == importScript
        && !cfg.boot.zfs.forceImportRoot
        && !cfg.boot.zfs.forceImportAll
        && cfg.boot.zfs.extraPools == [ ]
        && service.environment.BASTION_TANK_POOL_GUID == "7246454901288299061"
        && service.environment.BASTION_TANK_TOP_GUID == "10090352225522454630"
        && service.environment.BASTION_TANK_LEAF_GUIDS == "10490442266801898687 10971089219668578942"
        && lib.all (unit: lib.elem unit service.requiredBy) [
          "srv.mount"
          "srv-containers.mount"
          "srv-frigate.mount"
          "srv-immich.mount"
          "srv-nextcloud.mount"
          "srv-nixflix.mount"
          "srv-offsite\\x2dstage.mount"
          "srv-yuvomi.mount"
        ]
      ) "Bastion must retain its exact strict import policy and required dataset-mount dependencies";
      true
    );

  perSystem = { pkgs, ... }: {
    checks.bastion-import-policy =
      pkgs.runCommand "bastion-import-policy"
        {
          nativeBuildInputs = [
            pkgs.bash
            pkgs.python3
            pkgs.jq
            pkgs.gawk
            pkgs.coreutils
          ];
        }
        ''
          python3 ${./test-import-bastion-tank.py} ${./import-bastion-tank.sh}
          touch "$out"
        '';
  };
}
