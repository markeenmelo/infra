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
    fileSystems =
      lib.mapAttrs (_: device: {
        inherit device;
        fsType = "zfs";
      }) datasets
      // {
        "/mnt/backup" = {
          device = "/dev/disk/by-uuid/299d5130-226c-4d2f-b677-d4613da171db";
          fsType = "ext4";
          options = [
            "nofail"
            "x-systemd.automount"
            "x-systemd.device-timeout=5s"
            "x-systemd.mount-timeout=30s"
          ];
        };
      };
    services.zfs = {
      autoScrub = {
        enable = true;
        pools = [ "tank" ];
        interval = "monthly";
      };
      autoSnapshot.enable = true;
    };
  };
}
