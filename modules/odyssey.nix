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
    };
}
