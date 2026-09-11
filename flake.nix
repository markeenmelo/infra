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
    import-tree.url = "github:denful/import-tree";
    # Only the unstable interactive desktop needs Home Manager; servers do not.
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    # Normal default-branch flake, pinned only in flake.lock. The desktop calls
    # its source recipe with its own pkgs instead of importing another set.
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
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

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
