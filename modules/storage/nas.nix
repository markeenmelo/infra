{
  flake.modules.nixos.nas = { config, lib, ... }: {
    options.fleet.nas.storageReviewed = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "OS vs valuable-data inventory, pool import policy, backup/restore and service mount requirements reviewed.";
    };
    config.fleet.bootstrap.missing =
      lib.optional (!config.fleet.nas.storageReviewed)
        "Review NAS data inventory, import policy and backups/restore separately; acknowledge fleet.nas.storageReviewed. Never provision data disks through the OS layout.";
  };
}
