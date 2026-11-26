{
  flake.modules.nixos.gaming =
    { config, lib, ... }:
    let
      profiles = lib.getExe' config.services.power-profiles-daemon.package "powerprofilesctl";
    in
    {
      programs.steam.enable = true;
      programs.gamemode = {
        enable = true;
        settings.custom = {
          start = "${profiles} set performance";
          end = "${profiles} set power-saver";
        };
      };
      nixpkgs.config.allowUnfreePackages = [
        "steam"
        "steam-unwrapped"
      ];
    };
}
