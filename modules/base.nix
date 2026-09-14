{
  flake.modules.nixos.base =
    { lib, ... }:
    {
      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        auto-optimise-store = true;
      };
      documentation.nixos.enable = false;
      networking.useDHCP = lib.mkDefault false;
    };
}
