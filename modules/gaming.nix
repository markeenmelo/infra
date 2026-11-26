{ config, ... }:
let
  inherit (config.flake.modules) homeManager;
in
{
  flake.modules.nixos.gaming =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      profiles = lib.getExe' config.services.power-profiles-daemon.package "powerprofilesctl";
    in
    {
      programs.steam = {
        enable = true;
        extraCompatPackages = [ pkgs.proton-ge-bin ];
        protontricks.enable = true;
      };
      programs.gamemode = {
        enable = true;
        settings.custom = {
          start = "${profiles} set performance";
          end = "${profiles} set power-saver";
        };
      };
      home-manager.users.marcos.imports = [ homeManager.gaming ];
      nixpkgs.config.allowUnfreePackages = [
        "steam"
        "steam-unwrapped"
      ];
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
