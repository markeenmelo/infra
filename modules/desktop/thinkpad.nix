{
  fleet.hosts.thinkpad.module = { lib, ... }: {
    home-manager.users.marcos = {
      # Deliberate initial compatibility baseline for this NEW home configuration;
      # it is not derived from the moving Home Manager or Nixpkgs version.
      home.stateVersion = "26.05";
      xdg.configFile."hypr/hyprland.lua".text = lib.mkAfter ''
        -- Read-only local output inventory, 2026-09-09: Chimei Innolux 0x143F.
        -- Keep the internal display usable when an external display disconnects.
        hl.monitor({ output = "eDP-1", mode = "1920x1200@60.003",
                     position = "auto", scale = 1, cm = "srgb", bitdepth = 8, vrr = 0 })
      '';
    };
    # Samsung/eGPU are disconnected. The generic preferred-mode rule handles
    # ordinary external displays; HDR, VRR, high-refresh modes and NVIDIA driver
    # selection remain the explicit verification checklist in docs/desktop.md.
    # No PRIME bus IDs, cardN list, forced HDR metadata or automatic TB trust.
  };
}
