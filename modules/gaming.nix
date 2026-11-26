{
  flake.modules.nixos.gaming = {
    programs.steam.enable = true;
    nixpkgs.config.allowUnfreePackages = [
      "steam"
      "steam-unwrapped"
    ];
  };
}
