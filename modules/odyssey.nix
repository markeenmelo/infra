{
  flake.modules.nixos.desktop = {
    hardware.i2c.enable = true;
    users.users.marcos.extraGroups = [ "i2c" ];
  };

  flake.modules.homeManager.desktop =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.ddcutil ];
      programs.noctalia.settings.brightness.enable_ddcutil = true;
      wayland.windowManager.hyprland.settings.monitor = [
        {
          output = "desc:Samsung Electric Company Odyssey G93SC HCSY300098";
          position = "auto-center-up";
          mode = "5120x1440@120";
          scale = 1.25;
          vrr = 1;
          bitdepth = 10;
          cm = "hdr";
        }
      ];
    };
}
