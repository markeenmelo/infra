{
  flake.modules.nixos.base =
    { lib, ... }:
    let
      inherit (lib) mkOption types;
    in
    {
      options.fleet = {
        installation = {
          osDevice = mkOption {
            type = types.nullOr (types.strMatching "/dev/disk/by-(id|path)/[a-zA-Z0-9._:+-]+");
            default = null;
            apply =
              device:
              assert lib.assertMsg (
                device == null || builtins.match ".*-part[0-9]+" device == null
              ) "The installation device must be a whole OS disk, not a partition.";
              device;
            description = "Whole OS disk identity for the per-host disko layout. Each layout restricts its identifier policy; only Racknerd permits a PCI by-path exception when no serial/by-id exists.";
          };
        };
      };
      config = {
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
    };
}
