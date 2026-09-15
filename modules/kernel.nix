{
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
          message = "Fleet kernel policy requires a 7.x kernel; review policy before crossing major versions.";
        }
      ];
    };
}
