{ lib, ... }:
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

  fleet.validation.hostChecks.kernel =
    { name, system, ... }:
    let
      cfg = system.config;
    in
    assert lib.assertMsg
      (
        lib.versions.major cfg.boot.kernelPackages.kernel.version == "7"
        && cfg.boot.kernelPackages.kernel.drvPath == system.pkgs.linuxPackages_latest.kernel.drvPath
        && !(lib.elem "xe" cfg.boot.initrd.kernelModules)
        && !(lib.any (lib.hasInfix "force_probe") cfg.boot.kernelParams)
      )
      "${name}: retain the host track's latest stock 7.x kernel and no experimental Intel force-probe policy";
    true;
}
