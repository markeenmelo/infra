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
      programs.umbriel.settings.output."Samsung Electric Company Odyssey G93SC HCSY300098" = {
        mode = "5120x1440@120";
        layout.scrolling.default_extent_fraction = 1.0 / 3;
      };
    };
}
