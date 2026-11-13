{
  flake.modules.nixos.desktop = {
    hardware.i2c.enable = true;
    users.users.marcos.extraGroups = [ "i2c" ];
  };

  flake.modules.homeManager.desktop =
    { pkgs, ... }:
    let
      output = "desc:Samsung Electric Company Odyssey G93SC HCSY300098";
    in
    {
      home.packages = [ pkgs.ddcutil ];
      programs.noctalia.settings.brightness.enable_ddcutil = true;
      wayland.windowManager.hyprland.settings = {
        monitor = [
          {
            inherit output;
            position = "auto-center-up";
            mode = "5120x1440@120";
            scale = 1;
            vrr = 1;
            bitdepth = 10;
            cm = "hdr";
          }
        ];
        config.master = {
          orientation = "center";
          slave_count_for_center_master = 0;
          mfact = 0.5;
        };
        workspace_rule = [
          {
            workspace = "m[${output}]";
            layout = "master";
          }
          {
            workspace = "m[${output}]w[tv1]";
            gaps_out = {
              top = 6;
              bottom = 6;
              left = 1024;
              right = 1024;
            };
          }
        ];
      };
    };
}
