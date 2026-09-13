_: {
  fleet.hosts.thinkpad.module = _: {
    home-manager.users.marcos =
      { lib, ... }:
      {
        wayland.windowManager.hyprland.settings.monitor = lib.mkAfter [
          {
            output = "eDP-1";
            mode = "1920x1200@60.003";
            position = "0x0";
            scale = 1;
            cm = "srgb";
            bitdepth = 8;
            vrr = 0;
          }
        ];
      };
  };
}
