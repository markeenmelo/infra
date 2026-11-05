{
  flake.modules.nixos.base =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      zfs = config.boot.zfs.package.kernelModuleAttribute;
      releases = lib.filterAttrs (
        name: packages:
        builtins.match "linux_[0-9]+_[0-9]+" name != null && (builtins.tryEval packages).success
      ) pkgs.linuxKernel.packages;
      supported = lib.filter (packages: !packages.${zfs}.meta.broken) (lib.attrValues releases);
      newest = lib.last (lib.sort (a: b: lib.versionOlder a.kernel.version b.kernel.version) supported);
    in
    {
      boot.kernelPackages = lib.mkDefault (
        if config.boot.supportedFilesystems.zfs or false then newest else pkgs.linuxPackages_latest
      );
    };
}
