{
  flake.modules.nixos.base =
    { lib, pkgs, ... }:
    {
      boot.kernelPackages = lib.mkDefault (
        lib.last (
          lib.sort (a: b: lib.versionOlder a.kernel.version b.kernel.version) (
            lib.filter (packages: (lib.tryEval packages.kernel).success) (
              lib.attrValues (
                lib.filterAttrs (name: _: lib.match "linux_[0-9]+_[0-9]+" name != null) pkgs.linuxKernel.packages
              )
            )
          )
        )
      );
    };
}
