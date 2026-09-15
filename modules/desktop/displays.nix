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
        wayland.windowManager.hyprland.extraConfig = ''
          do
            local pending, panel_disabled = false, nil

            local function reconcile_panel()
              pending = false
              local file = io.open("/proc/acpi/button/lid/LID/state", "r")
              local lid = file and file:read("*a") or ""
              if file then file:close() end

              local disabled = false
              if lid:match("^state:%s+closed%s*$") then
                for _, monitor in ipairs(hl.get_monitors()) do
                  if monitor.name ~= "eDP-1" and monitor.name ~= "FALLBACK"
                    and not monitor.name:match("^HEADLESS%-%d+$")
                    and not monitor.name:match("^WAYLAND%-%d+$") then
                    disabled = true
                    break
                  end
                end
              end

              if panel_disabled ~= disabled then
                panel_disabled = disabled
                hl.monitor({ output = "eDP-1", disabled = disabled })
              end
            end

            local function queue_panel()
              if pending then return end
              pending = true
              hl.timer(reconcile_panel, { timeout = 50, type = "oneshot" })
            end

            hl.bind("switch:Lid Switch", queue_panel, { locked = true })
            for _, event in ipairs({
              "hyprland.start", "config.reloaded",
              "monitor.added", "monitor.removed", "monitor.layout_changed",
            }) do
              hl.on(event, queue_panel)
            end
          end
        '';
      };
  };
}
