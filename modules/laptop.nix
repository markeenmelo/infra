{
  flake.modules.nixos.laptop = {
    services.upower.enable = true;
    services.tlp = {
      enable = true;
      pd.enable = true;
      settings = {
        TLP_AUTO_SWITCH = 1;
        TLP_PROFILE_AC = "BAL";
        TLP_PROFILE_BAT = "SAV";
      };
    };
    environment.persistence."/persist".directories = [ "/var/lib/systemd/backlight" ];
  };
}
