{
  description = "Dendritic NixOS fleet: explicit release tracks and safe commissioning";

  inputs = {
    # Resolve the next stable release deliberately; see docs/research.md.
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    # Only the unstable interactive desktop needs Home Manager; servers do not.
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Normal default-branch flake, pinned only in flake.lock. The desktop calls
    # its source recipe with its own pkgs instead of importing another set.
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
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
    # Normal default-branch flake, pinned only in flake.lock.
    sops-nix = {
      url = "github:Mic92/sops-nix";
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
      # Production Nix files are top-level modules; devenv.nix is the separate
      # native development entry point and is never discovered here.
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
