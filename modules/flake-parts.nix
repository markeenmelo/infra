{ inputs, ... }:
{
  imports = [ inputs.flake-parts.flakeModules.modules ];
  systems = [
    "x86_64-linux"
    "aarch64-linux"
  ];
  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = inputs.nixpkgs.legacyPackages.${system};
    };
}
