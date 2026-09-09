{
  flake.modules.nixos.gaming = { config, lib, ... }: {
    options.fleet.gaming.reviewed = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Launchers, graphics, controllers, licensing and persistence have been deliberately selected (including none).";
    };
    config.fleet.bootstrap.missing =
      lib.optional (!config.fleet.gaming.reviewed)
        "Choose gaming software/driver policy and acknowledge fleet.gaming.reviewed; nothing proprietary is enabled implicitly.";
  };
}
