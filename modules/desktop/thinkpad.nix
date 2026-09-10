{
  fleet.hosts.thinkpad.module = { lib, ... }: {
    # Pre-activation desktop review, 2026-09-10: evaluated greeter session
    # (noctalia-greeter, no autologin), password-first PAM with bounded
    # fingerprint fallback and keyring hooks, Hyprland 0.56.2/UWSM, portals,
    # PipeWire, lock/idle policy, scoped KDE Connect exposure and Bluetooth
    # service with powerOnBoot false. Live session behavior, fingerprint
    # enrollment and peripherals are documented first-boot acceptance tests.
    fleet.desktop.reviewed = true;
    # Operator-run private audit, 2026-09-10: MAC/decryption and filled scalar
    # checks passed with the dedicated identity. No campus connection tested.
    fleet.wifi.senecaSopsFile = ../../secrets/hosts/thinkpad-senecanet.yaml;
    home-manager.users.marcos = {
      # Deliberate initial compatibility baseline for this NEW home configuration;
      # it is not derived from the moving Home Manager or Nixpkgs version.
      home.stateVersion = "26.05";
      # Chimei Innolux 0x143F, observed locally 2026-09-09. Keep the panel
      # available after undocking; let Home Manager generate the monitor call.
      wayland.windowManager.hyprland.settings.monitor = lib.mkAfter [
        {
          output = "eDP-1";
          mode = "1920x1200@60.003";
          position = "auto";
          scale = 1;
          cm = "srgb";
          bitdepth = 8;
          vrr = 0;
        }
      ];
    };
    # Samsung/eGPU are disconnected. The generic preferred-mode rule handles
    # ordinary external displays; HDR, VRR, high-refresh modes and NVIDIA driver
    # selection remain the explicit verification checklist in docs/desktop.md.
    # No PRIME bus IDs, cardN list, forced HDR metadata or automatic TB trust.
  };
}
