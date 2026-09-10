{
  fleet.hosts.thinkpad.module = _: {
    # Pre-activation desktop review, 2026-09-10: evaluated greeter session
    # (noctalia-greeter, no autologin), password-first PAM with bounded
    # fingerprint fallback and keyring hooks, Hyprland 0.56.2/UWSM, portals,
    # PipeWire, lock/idle policy, scoped KDE Connect exposure and Bluetooth.
    # Live session behavior, fingerprint
    # enrollment and peripherals are documented first-boot acceptance tests.
    fleet.desktop.reviewed = true;
    # Operator-run private audit, 2026-09-10: MAC/decryption and filled scalar
    # checks passed with the dedicated identity. No campus connection tested.
    fleet.wifi.senecaSopsFile = ../../secrets/hosts/thinkpad-senecanet.yaml;
    home-manager.users.marcos =
      { lib, pkgs, ... }:
      let
        inline = lib.generators.mkLuaInline;
        toLua = lib.generators.toLua { };
        outputPolicy = pkgs.writeShellApplication {
          name = "fleet-output-policy";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.edid-decode
            pkgs.gnugrep
            pkgs.hyprland
            pkgs.jq
            pkgs.socat
            pkgs.util-linux
          ];
          text = builtins.readFile ./assets/output-policy.sh;
        };
        policyCommand = action: "${lib.getExe pkgs.uwsm} app -- ${lib.getExe outputPolicy} ${action}";
        policyDispatch = action: inline "hl.dsp.exec_cmd(${toLua (policyCommand action)})";
      in
      {
        # Deliberate initial compatibility baseline for this NEW home configuration;
        # it is not derived from the moving Home Manager or Nixpkgs version.
        home.stateVersion = "26.05";
        wayland.windowManager.hyprland.settings = {
          # Chimei Innolux 0x143F, observed locally 2026-09-09. The runtime
          # policy keeps this exact safe rule when no external is present.
          monitor = lib.mkAfter [
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
          bind = lib.mkAfter [
            {
              _args = [
                "switch:on:Lid Switch"
                (policyDispatch "sync")
                { locked = true; }
              ];
            }
            {
              _args = [
                "switch:off:Lid Switch"
                (policyDispatch "sync")
                { locked = true; }
              ];
            }
          ];
          on = lib.mkAfter [
            {
              _args = [
                "hyprland.start"
                (inline ''
                  function()
                    hl.exec_cmd(${toLua (policyCommand "watch")})
                  end
                '')
              ];
            }
          ];
        };
      };
    # Read-only live/EDID review on 2026-09-10 confirmed the Samsung Odyssey's
    # preferred 5120x1440 mode, PQ/BT.2020 HDR metadata and 10-bit capability.
    # The generic policy still checks each connected EDID before enabling HDR,
    # arranges externals above eDP-1 and never assumes a cardN/PRIME/eGPU path.
  };
}
