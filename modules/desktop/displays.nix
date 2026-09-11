{ config, ... }:
let
  # Verified ThinkPad panel facts, shared by the static rule and runtime policy.
  internal = {
    output = "eDP-1";
    mode = "1920x1200@60.003";
    width = 1920;
  };
  outputPolicyText =
    builtins.replaceStrings
      [ "@internalOutput@" "@internalMode@" "@internalWidth@" ]
      [ internal.output internal.mode (toString internal.width) ]
      (builtins.readFile ./assets/output-policy.sh);
in
{
  fleet.hosts.thinkpad.module = _: {
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
            pkgs.hyprland
            pkgs.jq
            pkgs.socat
            pkgs.util-linux
          ];
          text = outputPolicyText;
        };
        policyCommand = action: "${lib.getExe pkgs.uwsm} app -- ${lib.getExe outputPolicy} ${action}";
        policyDispatch = action: inline "hl.dsp.exec_cmd(${toLua (policyCommand action)})";
      in
      {
        wayland.windowManager.hyprland.settings = {
          # Chimei Innolux 0x143F, observed locally 2026-09-09. The runtime
          # policy keeps this exact safe rule when no external is present.
          monitor = lib.mkAfter [
            {
              inherit (internal) output mode;
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
  perSystem.checks = {
    thinkpad-output-policy =
      let
        targetPkgs = config.flake.fleetConfigurations.thinkpad.pkgs;
        script = targetPkgs.writeText "output-policy.sh" outputPolicyText;
      in
      targetPkgs.runCommand "thinkpad-output-policy"
        {
          nativeBuildInputs = with targetPkgs; [
            bash
            coreutils
            hyprland
            jq
            python3
            shellcheck
            socat
            util-linux
          ];
        }
        ''
          shellcheck ${script}
          python3 ${./assets/test-output-policy.py} ${script}
          touch "$out"
        '';
  };
}
