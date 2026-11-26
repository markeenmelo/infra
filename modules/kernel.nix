{
  flake.modules.nixos.base =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      zfs = config.boot.supportedFilesystems.zfs or false;
      nvidia = config.hardware.nvidia.enabled;
      builds =
        packages:
        lib.optional zfs packages.${config.boot.zfs.package.kernelModuleAttribute}
        # shortcut: checks the default stable driver, not hardware.nvidia.package, which is chosen from boot.kernelPackages itself; follow the chosen driver when a host picks dc, beta or a pinned one
        ++ lib.optional nvidia (
          if config.hardware.nvidia.open then
            packages.nvidiaPackages.stable.open
          else
            packages.nvidiaPackages.stable
        );
      releases = lib.filterAttrs (
        name: packages:
        builtins.match "linux_[0-9]+_[0-9]+" name != null && (builtins.tryEval packages).success
      ) pkgs.linuxKernel.packages;
      supported = lib.filter (packages: lib.all (module: !module.meta.broken) (builds packages)) (
        lib.attrValues releases
      );
      newest = lib.last (lib.sort (a: b: lib.versionOlder a.kernel.version b.kernel.version) supported);
    in
    {
      boot.kernelPackages = lib.mkDefault (if zfs || nvidia then newest else pkgs.linuxPackages_latest);
    };
}
