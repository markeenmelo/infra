{
  flake.modules.nixos.vps = { config, lib, ... }: {
    options.fleet.vps.providerReviewed = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Provider boot, networking, virtualization and rescue-console facts have been verified.";
    };
    config.fleet.bootstrap.missing = lib.optional (
      !config.fleet.vps.providerReviewed
    ) "Supply provider-specific facts separately; acknowledge fleet.vps.providerReviewed.";
  };
}
