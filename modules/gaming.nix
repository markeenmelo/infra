{ config, ... }:
let
  inherit (config.flake.modules) homeManager;
  inherit (config.flake.modules.nixos) steam;
in
{
  flake.modules.nixos.steam =
    { pkgs, ... }:
    {
      programs.steam = {
        enable = true;
        extraCompatPackages = [ pkgs.proton-ge-bin ];
        protontricks.enable = true;
      };
      nixpkgs.config.allowUnfreePackages = [
        "steam"
        "steam-unwrapped"
      ];
    };

  flake.modules.nixos.gaming =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      profiles = lib.getExe' config.services.power-profiles-daemon.package "powerprofilesctl";
      systemd = config.systemd.package;
    in
    {
      imports = [ steam ];
      programs.gamemode = {
        enable = true;
        settings.custom = {
          start = "${systemd}/bin/systemd-run --user --collect --unit=gamemode-performance ${profiles} launch --profile performance --reason GameMode ${pkgs.coreutils}/bin/sleep infinity";
          end = "${systemd}/bin/systemctl --user stop gamemode-performance";
        };
      };
      home-manager.users.marcos.imports = [ homeManager.gaming ];
    };

  flake.modules.homeManager.gaming = {
    programs.mangohud = {
      enable = true;
      settings = {
        no_display = true;
        toggle_hud = "Shift_R+F12";
        horizontal = true;
        fps = true;
        frametime = true;
        cpu_stats = true;
        cpu_temp = true;
        gpu_stats = true;
        gpu_temp = true;
      };
    };
    programs.umbriel.settings.window_rule = [
      {
        match.app_id = "^steam_app_.*$";
        tearing = true;
        vrr = "always";
        confine_pointer = true;
      }
    ];
  };
}
