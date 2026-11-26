{ config, ... }:
let
  inherit (config.flake.modules.nixos) operator-login;
in
{
  flake.modules.nixos.kiosk =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      session = {
        user = "ian";
        command = "${lib.getExe config.programs.gamescope.package} --fullscreen -- ${lib.getExe pkgs.prismlauncher}";
      };
    in
    {
      imports = [ operator-login ];
      users.users.ian = {
        isNormalUser = true;
        uid = 1001;
        description = "Ian";
        extraGroups = [
          "audio"
          "video"
          "input"
        ];
      };
      services.greetd = {
        enable = true;
        restart = true;
        settings = {
          initial_session = session;
          default_session = session;
        };
      };
      programs.gamescope.enable = true;
      hardware = {
        graphics.enable = true;
        bluetooth.enable = true;
      };
      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        pulse.enable = true;
      };
      powerManagement.cpuFreqGovernor = "performance";
      nix = {
        settings.max-jobs = 0;
        gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 14d";
        };
      };
    };
}
