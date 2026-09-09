{
  # Latest stock kernel from EACH host's locked track; never borrow a server's
  # kernel from unstable. Updates remain explicit flake-lock operations.
  flake.modules.nixos.base =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      boot.kernelPackages = pkgs.linuxPackages_latest;
      assertions = [
        {
          assertion = lib.versions.major config.boot.kernelPackages.kernel.version == "7";
          message = "Fleet kernel policy requires the latest stock 7.x kernel from the host track; review policy before crossing major versions.";
        }
        {
          assertion = config.boot.kernelPackages.kernel.drvPath == pkgs.linuxPackages_latest.kernel.drvPath;
          message = "Fleet hosts must use their own track's latest stock kernel, not a mixed-track or patched kernel.";
        }
      ];
      # Upstream ZFS compatibility/broken-package assertions stay enabled. A future
      # latest-kernel update unsupported by ZFS must fail validation, not force-load.
    };
}
