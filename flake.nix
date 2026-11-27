{
  description = "Dendritic NixOS fleet";

  outputs =
    { self }:
    let
      inputs = import ./.tack { };
    in
    inputs.flake-parts.lib.mkFlake { inherit inputs self; } (
      inputs.import-tree.filterNot (inputs.nixpkgs.lib.hasSuffix ".pkg.nix") ./modules
    );
}
