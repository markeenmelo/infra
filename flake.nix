{
  description = "Dendritic NixOS fleet: explicit release tracks and safe commissioning";

  inputs = {
    # Resolve the next stable release deliberately; see docs/research.md.
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs-stable";
    };
    # Only the unstable interactive desktop needs Home Manager; servers do not.
    home-manager-unstable = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    # Zen is not in this Nixpkgs pin. Import only its locked source recipe with
    # the desktop's own pkgs, never the upstream flake's separate package set.
    zen-browser-src = {
      url = "github:youwen5/zen-browser-flake/3aadc420e763a8243aedd2ce925ae1dc13663ed9";
      flake = false;
    };
    disko = {
      url = "github:nix-community/disko";
      # Only upstream tools use this input. The NixOS module uses its caller's pkgs/lib.
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
    impermanence = {
      url = "github:nix-community/impermanence";
      # Upstream explicitly permits removing these development-only dependencies.
      inputs.nixpkgs.follows = "";
      inputs.home-manager.follows = "";
    };
    sops-nix = {
      # Reuse the existing credential backend pin; see docs/research.md.
      url = "github:Mic92/sops-nix/fbf759290e0cb0a98dfc813a4eb7d53ad1dacb57";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      # Every repository Nix file other than this entry point is a top-level module.
      # readDir is sorted; symlinks are not followed. No discovery dependency needed.
      imports =
        let
          discover =
            dir:
            builtins.concatLists (
              builtins.attrValues (
                builtins.mapAttrs (
                  name: type:
                  if type == "directory" then
                    discover (dir + "/${name}")
                  else if type == "regular" && builtins.match ".*\\.nix" name != null then
                    [ (dir + "/${name}") ]
                  else
                    [ ]
                ) (builtins.readDir dir)
              )
            );
        in
        [ inputs.flake-parts.flakeModules.modules ] ++ discover ./modules;
      systems = [ "x86_64-linux" ];
    };
}
