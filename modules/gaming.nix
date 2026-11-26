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
      ...
    }:
    let
      profiles = lib.getExe' config.services.power-profiles-daemon.package "powerprofilesctl";
    in
    {
      options.gaming.restProfile = lib.mkOption {
        type = lib.types.enum [
          "power-saver"
          "balanced"
        ];
        default = "balanced";
        description = "Power profile GameMode sets when the last game exits.";
      };
      imports = [ steam ];
      config = {
        programs.gamemode = {
          enable = true;
          settings.custom = {
            start = "${profiles} set performance";
            end = "${profiles} set ${config.gaming.restProfile}";
          };
        };
        home-manager.users.marcos.imports = [ homeManager.gaming ];
      };
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
