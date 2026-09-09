{
  flake.modules.nixos.nas = { config, lib, ... }: {
    options.fleet.nas.storageReviewed = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "OS vs valuable-data disk inventory, backup/recovery plan and proposed NAS services reviewed.";
    };
    config.fleet.bootstrap.missing =
      lib.optional (!config.fleet.nas.storageReviewed)
        "Review NAS data inventory/backups separately; acknowledge fleet.nas.storageReviewed. No NAS disks/shares are configured.";
  };
}
