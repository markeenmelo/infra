{
  description = "Dendritic NixOS fleet";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    import-tree.url = "github:denful/import-tree";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    preservation.url = "github:nix-community/preservation";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "";
      };
    };
    stylix = {
      url = "github:nix-community/stylix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
      };
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };
    nixflix = {
      url = "github:kiriwalawren/nixflix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        mkdocs-catppuccin.follows = "";
        treefmt-nix.follows = "";
      };
    };
    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        spectrum.follows = "";
      };
    };
    hermes-agent = {
      url = "github:NousResearch/hermes-agent/v0.23.4";
      inputs = {
        flake-parts.follows = "flake-parts";
        home-manager.follows = "home-manager";
      };
    };
    paseo = {
      url = "github:getpaseo/paseo";
      inputs.nixpkgs.follows = "";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      inputs.import-tree.filterNot (inputs.nixpkgs.lib.hasSuffix ".pkg.nix") ./modules
    );
}
