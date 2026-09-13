{ config, lib, ... }:
let
  internal = {
    output = "eDP-1";
    mode = "1920x1200@60.003";
  };
  outputPolicyText =
    builtins.replaceStrings
      [ "@internalOutput@" "@internalMode@" ]
      [ internal.output internal.mode ]
      (builtins.readFile ../../scripts/desktop/output-policy.sh);
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
          monitor = lib.mkAfter [
            {
              inherit (internal) output mode;
              position = "0x0";
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
  };
  perSystem.checks = {
    thinkpad-output-policy =
      let
        target = config.flake.fleetConfigurations.thinkpad;
        targetPkgs = target.pkgs;
        rules = target.config.home-manager.users.marcos.wayland.windowManager.hyprland.settings.monitor;
        script = targetPkgs.writeText "output-policy.sh" outputPolicyText;
      in
      assert lib.assertMsg (
        lib.any (rule: rule.output == "" && rule.mode == "preferred" && rule.position == "auto-center-up" && rule.scale == 1) rules
        && lib.any (rule: rule.output == "eDP-1" && rule.mode == "1920x1200@60.003" && rule.position == "0x0" && rule.scale == 1) rules
      ) "ThinkPad static defaults must center connector-independent preferred externals above the observed panel before the watcher starts.";
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
          python3 ${../../scripts/desktop/test-output-policy.py} ${script}
          touch "$out"
        '';
  };
}
