{
  fleet.hosts.thinkpad.module = {
    home-manager.users.marcos =
      { lib, ... }:
      {
        wayland.windowManager.hyprland.settings.monitor = lib.mkAfter [
          {
            output = "eDP-1";
            mode = "highres";
            position = "0x0";
            scale = 1;
            cm = "srgb";
            bitdepth = 8;
            vrr = 0;
          }
          {
            output = "desc:Samsung Electric Company Odyssey G93SC";
            mode = "maxwidth";
            position = "auto-center-up";
            scale = 1;
            cm = "srgb";
            bitdepth = 8;
            vrr = 0;
          }
        ];
      };
  };
}
